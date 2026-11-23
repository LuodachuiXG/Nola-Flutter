import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import 'async_value_widget.dart' show EmptyPlaceholder;
import 'markdown_preview_html.dart';

/// 当前平台是否支持 WebView 预览（webview_flutter 无 Windows / Linux 实现）。
bool get _previewSupported =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.linux);

/// 编辑器 → 预览滚动同步的节流间隔。
///
/// macOS 的 JS 桥每次调用开销很大（且当前版本有缺陷）：过小会拖垮编辑器
/// 的惯性滚动，过大则预览跟随发虚卡顿。默认 33ms（约 30 次/秒），
/// 可按实际手感整体调整这一个值。
const Duration kPreviewScrollSyncInterval = Duration(milliseconds: 33);

/// Markdown 预览视图（WebView 渲染，与 Nola-Apple 实现保持一致）。
///
/// 使用 Nola-Apple 的 markdown.html 模板（marked + highlight.js +
/// Tailwind prose + JetBrains Mono），暗色模式跟随 Flutter 主题。
///
/// 两条渲染管线：
/// - **JS 桥管线**（Android / iOS / Web）：加载模板后通过
///   `runJavaScript` 增量渲染内容与切换暗色；
/// - **烘焙重载管线**（macOS）：WKWebView 的 JS 桥在 macOS 上全面损坏
///   （evaluateJavaScript 恒报错、通道与导航事件不投递），因此把主题、
///   内容与滚动位置直接烘焙进 HTML 重新加载（`buildPreviewDocument`）。
class MarkdownPreviewView extends StatefulWidget {
  const MarkdownPreviewView({
    super.key,
    required this.content,
    this.isMarkdown = true,
    this.initialScrollFraction = 0,
    this.onPreviewScroll,
  });

  /// 要渲染的内容（Markdown 或 HTML）。
  final String content;

  /// 内容是否为 Markdown（false 时按 HTML 直出）。
  final bool isMarkdown;

  /// 初始滚动位置比例（0~1），仅在首次加载时应用。
  ///
  /// 用于窄屏模式下切到预览时接续编辑器的阅读位置。
  final double initialScrollFraction;

  /// 预览页滚动比例（0~1，滚到底为 1）的回报回调。
  ///
  /// 非空时会在加载前注册 `PreviewScroll` JS 通道；
  /// 仅桥接正常的平台（Android / iOS / Web）会收到回报，
  /// macOS 的 JS 桥损坏，不会触发。
  final ValueChanged<double>? onPreviewScroll;

  @override
  State<MarkdownPreviewView> createState() => MarkdownPreviewViewState();
}

class MarkdownPreviewViewState extends State<MarkdownPreviewView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => _render(widget.content),
      ),
    );

  /// 页面是否加载完成（加载完成后内容更新走 JS 注入）。
  bool _pageLoaded = false;

  /// 当前是否暗色主题（与 Flutter Theme 保持一致）。
  bool _dark = false;

  /// 最近一次的编辑器滚动比例，烘焙重载时用于恢复预览位置。
  double _lastScrollFraction = 0;

  /// 烘焙重载管线的内容防抖。
  Timer? _reloadDebounce;

  /// 编辑器滚动同步的节流：滚动期间限制 JS 桥调用频率。
  ///
  /// macOS 的 JS 桥每次调用开销极大（且当前版本有缺陷），逐帧同步会把
  /// 平台线程拖垮，导致编辑器滚动惯性被掐断；节流到 ~12 次/秒，人眼
  /// 几乎无感知， trailing flush 保证停止位置准确。
  Timer? _scrollSyncThrottle;

  /// 上次实际下发预览滚动的时间戳（毫秒）。
  int _lastScrollDispatchMs = 0;

  /// 节流窗口内最新待下发的滚动比例。
  double? _pendingScrollFraction;

  /// macOS 走烘焙重载管线，其余平台走 JS 桥管线。
  bool get _useReloadPipeline =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    // 不支持的平台不初始化 WebView，避免 MissingPluginException
    if (!_previewSupported) return;
    _lastScrollFraction = widget.initialScrollFraction;
    // JS 通道必须在加载页面之前注册（WKUserScript 只注入后续导航）。
    if (widget.onPreviewScroll != null) {
      _controller.addJavaScriptChannel(
        'PreviewScroll',
        onMessageReceived: (message) {
          final fraction = double.tryParse(message.message);
          if (fraction != null) widget.onPreviewScroll!(fraction);
        },
      );
    }
    _loadAndRender();
  }

  Future<void> _loadAndRender() async {
    final html = await loadMarkdownPreviewHtml();
    if (!mounted) return;
    if (_useReloadPipeline) {
      await _reload();
      return;
    }
    await _controller.loadHtmlString(html);
    if (!mounted) return;
    _pageLoaded = true;
    _applyDarkMode();
    _render(widget.content);
    // 接续切换前的阅读位置（窄屏模式切到预览时）
    if (_lastScrollFraction > 0) {
      _dispatchScrollToPreview(_lastScrollFraction);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    // 加载完成前预置背景色，避免暗色主题下短暂白屏。
    // WKWebView 的 macOS 实现暂不支持背景色（调用即抛 UnimplementedError），
    // Web 平台同样未实现，这两端跳过。
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      _controller.setBackgroundColor(theme.colorScheme.surface);
    }
    final dark = theme.brightness == Brightness.dark;
    if (dark == _dark) return;
    _dark = dark;
    if (!_pageLoaded) return;
    if (_useReloadPipeline) {
      _reload();
    } else {
      _applyDarkMode();
    }
  }

  @override
  void didUpdateWidget(MarkdownPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content == widget.content &&
        oldWidget.isMarkdown == widget.isMarkdown) {
      return;
    }
    if (_useReloadPipeline) {
      // 输入期间内容频繁变化，防抖后整体重载
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(const Duration(milliseconds: 300), _reload);
    } else {
      _render(widget.content);
    }
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _scrollSyncThrottle?.cancel();
    super.dispose();
  }

  /// 编辑器滚动时同步预览位置（[fraction] 为 0~1 的滚动比例）。
  ///
  /// 桥接正常的平台直接调用页面内的 `window.__scrollToFraction`；
  /// macOS 桥损坏时调用无效果，滚动位置会在下次烘焙重载时通过
  /// 内嵌脚本恢复。
  void notifyEditorScroll(double fraction) {
    _lastScrollFraction = fraction;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollDispatchMs < kPreviewScrollSyncInterval.inMilliseconds) {
      // 节流窗口内只记录最新比例，窗口结束后补发
      _pendingScrollFraction = fraction;
      _scrollSyncThrottle ??= Timer(kPreviewScrollSyncInterval, () {
        _scrollSyncThrottle = null;
        final pending = _pendingScrollFraction;
        if (pending != null) {
          _pendingScrollFraction = null;
          _dispatchScrollToPreview(pending);
        }
      });
      return;
    }
    _dispatchScrollToPreview(fraction);
  }

  /// 实际通过 JS 桥下发预览滚动位置。
  void _dispatchScrollToPreview(double fraction) {
    _lastScrollDispatchMs = DateTime.now().millisecondsSinceEpoch;
    _controller.runJavaScript('window.__scrollToFraction($fraction);');
  }

  /// 烘焙重载管线：把主题 / 内容 / 滚动位置烘焙进 HTML 并重新加载。
  Future<void> _reload() async {
    final base = await loadMarkdownPreviewHtml();
    if (!mounted) return;
    final document = buildPreviewDocument(
      baseHtml: base,
      content: widget.content,
      isMarkdown: widget.isMarkdown,
      dark: _dark,
      initialScrollFraction: _lastScrollFraction,
    );
    await _controller.loadHtmlString(document);
    if (!mounted) return;
    _pageLoaded = true;
  }

  /// 将当前亮暗主题同步到预览页面（JS 桥管线）。
  void _applyDarkMode() {
    _controller.runJavaScript(buildSetDarkScript(_dark));
  }

  /// 渲染当前内容（JS 桥管线）。
  void _render(String content) {
    if (!_pageLoaded) return;
    _controller.runJavaScript(
      buildRenderScript(content, isMarkdown: widget.isMarkdown),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_previewSupported) {
      return const EmptyPlaceholder(
        icon: Icons.visibility_off_outlined,
        message: '当前平台暂不支持预览',
      );
    }
    return WebViewWidget(controller: _controller);
  }
}

/// 预览 HTML 缓存（资源不变，进程内只构建一次）。
Future<String>? _htmlFuture;

/// 加载并构建自包含的预览 HTML。
///
/// 将模板引用的 CSS / JS 与 JetBrains Mono 字体（Base64）全部内联，
/// 以便 WebView 直接通过 `loadHtmlString` 加载。
Future<String> loadMarkdownPreviewHtml() {
  return _htmlFuture ??= _buildHtml();
}

Future<String> _buildHtml() async {
  final template = await rootBundle.loadString('assets/markdown/markdown.html');
  final css = await rootBundle.loadString('assets/markdown/highlight.min.css');
  final highlightJs =
      await rootBundle.loadString('assets/markdown/highlight.min.js');
  final markedJs = await rootBundle.loadString('assets/markdown/marked.min.js');
  final tailwindJs = await rootBundle.loadString('assets/markdown/tailwind.js');
  final tailwindFormsJs =
      await rootBundle.loadString('assets/markdown/tailwind.forms.js');
  final fontData =
      await rootBundle.load('assets/markdown/JetBrainsMono-Regular.woff2');

  return buildMarkdownHtml(
    template: template,
    css: css,
    highlightJs: highlightJs,
    markedJs: markedJs,
    tailwindJs: tailwindJs,
    tailwindFormsJs: tailwindFormsJs,
    fontBase64: base64Encode(fontData.buffer.asUint8List()),
  );
}
