import 'package:dio/dio.dart' show Dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/models/post.dart';
import 'package:nola/core/network/api_client.dart';
import 'package:nola/features/posts/data/post_api.dart';
import 'package:nola/features/posts/providers/post_providers.dart';
import 'package:nola/features/posts/ui/post_edit_screen.dart';
import 'package:nola/shared/widgets/markdown_preview_view.dart'
    show loadMarkdownPreviewHtml;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// 宽屏取分屏断点（1000）处的最小宽度，同时覆盖顶栏布局是否会溢出
const _wideSize = Size(1000, 900);
const _narrowSize = Size(800, 900);

// 每行足够长：分屏窄宽度下会换行、单栏宽度下不换行，覆盖重排后的位置恢复
final String _longContent = List.generate(
  200,
  (i) => '第 $i 行：用于验证滚动位置保持的测试内容，需要足够长以在分屏窄宽度下换行',
).join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 预热全局 HTML 缓存，避免首个用例中未完成的资源加载影响后续用例
    await loadMarkdownPreviewHtml();
  });

  setUp(() {
    // 测试环境没有原生 WebView，用假实现替换平台层
    WebViewPlatform.instance = _FakeWebViewPlatform();
    _FakeWebViewPlatform.clearJsCalls();
  });

  testWidgets(
    '宽窄布局切换后保持编辑器滚动位置',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      _setViewSize(tester, _narrowSize);
      await _pumpEditor(tester);

      var position = _editorPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent * 0.5);
      await tester.pumpAndSettle();

      // 窄屏 → 宽屏分屏，编辑框不应重建或回到顶部
      _setViewSize(tester, _wideSize);
      await tester.pumpAndSettle();
      position = _editorPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(
        position.pixels / position.maxScrollExtent,
        closeTo(0.5, 0.02),
        reason: '进入分屏后编辑器应保持窄屏时的阅读位置',
      );

      // 分屏中滚到 40% 再缩回窄屏，验证同样保持位置（回归场景）
      position.jumpTo(position.maxScrollExtent * 0.4);
      await tester.pumpAndSettle();
      final wideFraction = position.pixels / position.maxScrollExtent;

      _setViewSize(tester, _narrowSize);
      await tester.pumpAndSettle();
      final narrowPosition = _editorPosition(tester);
      expect(narrowPosition.pixels, greaterThan(0), reason: '缩回窄屏后不应回到文章顶部');
      expect(
        narrowPosition.pixels / narrowPosition.maxScrollExtent,
        closeTo(wideFraction, 0.02),
        reason: '缩回窄屏后应保持分屏时的阅读位置',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '打开文章后编辑器默认停在文章顶部',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      _setViewSize(tester, _wideSize);
      await _pumpEditor(tester);

      final position = _editorPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, 0, reason: '刚打开文章时编辑器和预览都应显示文章开头');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '滚动同步使用带文字的开关，开启时立即同步预览',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      _setViewSize(tester, _wideSize);
      await _pumpEditor(tester);
      await _waitForPreviewLoaded(tester);

      expect(find.text('滚动同步'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // 关闭同步后滚动编辑器，不应再向预览下发滚动指令
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      final position = _editorPosition(tester);
      position.jumpTo(position.maxScrollExtent * 0.6);
      await tester.pumpAndSettle();
      _FakeWebViewPlatform.clearJsCalls();

      // 重新开启应立即以编辑器为准同步一次预览
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      final scrollCalls = _FakeWebViewPlatform.jsCalls
          .map(_scrollFractionOf)
          .whereType<double>()
          .toList();
      expect(scrollCalls, isNotEmpty, reason: '开启同步后应立即下发一次预览滚动位置');
      expect(scrollCalls.last, closeTo(0.6, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('编辑草稿时输入不清空草稿名，保存更新当前草稿', () async {
    final api = _FakePostApi(_longContent);
    final container = ProviderContainer.test(
      overrides: [postApiProvider.overrideWithValue(api)],
    );
    await container.read(postEditorProvider(1).future);
    final notifier = container.read(postEditorProvider(1).notifier);

    await notifier.loadDraft('草稿A');
    notifier.updateContent('修改后的草稿内容');

    final edited = container.read(postEditorProvider(1)).requireValue;
    expect(edited.draftName, '草稿A', reason: '输入内容不应清空当前草稿名');
    expect(edited.dirty, isTrue);

    await notifier.saveDraft(edited.draftName!);
    expect(api.updatedDrafts, hasLength(1));
    expect(api.updatedDrafts.single.content, '修改后的草稿内容');
    expect(api.updatedDrafts.single.draftName, '草稿A');
    expect(api.addedDrafts, isEmpty, reason: '保存已有草稿应走更新而不是新建');

    final saved = container.read(postEditorProvider(1)).requireValue;
    expect(saved.dirty, isFalse);
    expect(saved.tab, EditorTab.draft);
    expect(saved.draftName, '草稿A');
  });

  testWidgets(
    '草稿编辑显示保存按钮，按钮与快捷键都能保存草稿',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      _setViewSize(tester, _wideSize);
      final api = _FakePostApi(_longContent);
      await _pumpEditor(tester, api: api);

      // 从草稿列表加载草稿
      await tester.tap(find.text('草稿'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('草稿A'));
      await tester.pumpAndSettle();

      expect(find.text('保存草稿'), findsOneWidget);

      // 输入后草稿名仍保留，快捷键可以保存
      await tester.enterText(find.byType(TextField), '修改后的草稿内容');
      await tester.pumpAndSettle();
      expect(find.text('保存草稿'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(api.updatedDrafts, hasLength(1));
      expect(api.updatedDrafts.last.content, '修改后的草稿内容');
      expect(api.updatedDrafts.last.draftName, '草稿A');

      // 顶栏按钮同样可以保存
      await tester.tap(find.text('保存草稿'));
      await tester.pumpAndSettle();
      expect(api.updatedDrafts, hasLength(2));

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

void _setViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  _FakePostApi? api,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postApiProvider
            .overrideWithValue(api ?? _FakePostApi(_longContent)),
      ],
      child: const MaterialApp(home: PostEditScreen(postId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 等待预览 WebView 完成页面加载（加载后会发出渲染 / 主题 JS 调用）。
Future<void> _waitForPreviewLoaded(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (_FakeWebViewPlatform.jsCalls
        .any((js) => !js.contains('__scrollToFraction'))) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('预览页面加载超时');
}

ScrollPosition _editorPosition(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

final RegExp _scrollFractionPattern = RegExp(r'__scrollToFraction\(([^)]+)\)');

double? _scrollFractionOf(String javaScript) {
  final match = _scrollFractionPattern.firstMatch(javaScript);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

class _FakePostApi extends PostApi {
  _FakePostApi(this._content) : super(ApiClient(Dio()));

  final String _content;

  /// 已保存的草稿内容（加载草稿时返回）。
  String draftContent = '草稿内容';

  final List<({String content, String draftName})> updatedDrafts = [];
  final List<({String content, String draftName})> addedDrafts = [];

  @override
  Future<Post?> post(int postId) async => Post.fromJson({
        'postId': postId,
        'title': '测试文章',
        'status': 'PUBLISHED',
        'visible': 'VISIBLE',
      });

  @override
  Future<List<PostContentMeta>> postContents(int postId) async => [
        PostContentMeta.fromJson({
          'postContentId': 2,
          'postId': postId,
          'status': 'DRAFT',
          'draftName': '草稿A',
        }),
      ];

  @override
  Future<PostContent> postPublishContent(int postId) async =>
      PostContent.fromJson({
        'postContentId': 1,
        'postId': postId,
        'content': _content,
        'status': 'PUBLISHED',
      });

  @override
  Future<PostContent> postDraftContent(int postId, String draftName) async =>
      PostContent.fromJson({
        'postContentId': 2,
        'postId': postId,
        'content': draftContent,
        'status': 'DRAFT',
        'draftName': draftName,
      });

  @override
  Future<bool> updateDraft({
    required int postId,
    required String content,
    required String draftName,
  }) async {
    updatedDrafts.add((content: content, draftName: draftName));
    draftContent = content;
    return true;
  }

  @override
  Future<bool> addDraft({
    required int postId,
    required String content,
    required String draftName,
  }) async {
    addedDrafts.add((content: content, draftName: draftName));
    draftContent = content;
    return true;
  }
}

class _FakeWebViewPlatform extends WebViewPlatform {
  static final List<String> jsCalls = <String>[];

  static void clearJsCalls() => jsCalls.clear();

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      _FakeCookieManager(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _FakeNavigationDelegate(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {
    _FakeWebViewPlatform.jsCalls.add(javaScript);
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeCookieManager extends PlatformWebViewCookieManager {
  _FakeCookieManager(super.params) : super.implementation();
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(
    HttpAuthRequestCallback handler,
  ) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
}
