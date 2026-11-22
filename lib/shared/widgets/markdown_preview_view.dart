import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'async_value_widget.dart' show EmptyPlaceholder;
import 'markdown_preview_html.dart';

/// 当前平台是否支持 WebView 预览（webview_flutter 无 Windows / Linux 实现）。
bool get _previewSupported =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.linux);

/// Markdown 预览视图（WebView 渲染，与 Nola-Apple 实现保持一致）。
///
/// 使用 Nola-Apple 的 markdown.html 模板（marked + highlight.js +
/// Tailwind prose + JetBrains Mono），支持系统暗色模式自动适配。
class MarkdownPreviewView extends StatefulWidget {
  const MarkdownPreviewView({
    super.key,
    required this.content,
    this.isMarkdown = true,
  });

  /// 要渲染的内容（Markdown 或 HTML）。
  final String content;

  /// 内容是否为 Markdown（false 时按 HTML 直出）。
  final bool isMarkdown;

  @override
  State<MarkdownPreviewView> createState() => _MarkdownPreviewViewState();
}

class _MarkdownPreviewViewState extends State<MarkdownPreviewView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => _render(widget.content),
      ),
    );

  /// 页面是否加载完成（加载完成后内容更新走 JS 注入）。
  bool _pageLoaded = false;

  @override
  void initState() {
    super.initState();
    // 不支持的平台不初始化 WebView，避免 MissingPluginException
    if (!_previewSupported) return;
    loadMarkdownPreviewHtml().then((html) {
      return _controller.loadHtmlString(html);
    }).then((_) {
      if (!mounted) return;
      _pageLoaded = true;
      _render(widget.content);
    });
  }

  /// 渲染当前内容。
  void _render(String content) {
    if (!_pageLoaded) return;
    _controller.runJavaScript(
      buildRenderScript(content, isMarkdown: widget.isMarkdown),
    );
  }

  @override
  void didUpdateWidget(MarkdownPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.isMarkdown != widget.isMarkdown) {
      _render(widget.content);
    }
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
