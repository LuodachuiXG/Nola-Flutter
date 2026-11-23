import 'package:flutter_test/flutter_test.dart';
import 'package:nola/shared/widgets/markdown_preview_html.dart';
import 'package:nola/shared/widgets/markdown_preview_view.dart'
    show loadMarkdownPreviewHtml;

/// Markdown 预览 HTML 构建回归测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const template = '''
<!DOCTYPE html>
<html>
  <head>
    <style>
      @font-face {
        src: url('JetBrainsMono-Regular.woff2') format('woff2');
      }
    </style>
    <link rel="stylesheet" href="highlight.min.css">
    <script src="highlight.min.js"></script>
    <script src="tailwind.js"></script>
    <script src="tailwind.forms.js"></script>
  </head>
  <body>
    <div id="content"></div>
    <script src="marked.min.js"></script>
  </body>
</html>
''';

  test('buildMarkdownHtml 内联全部资源引用', () {
    final html = buildMarkdownHtml(
      template: template,
      css: '/* CSS */',
      highlightJs: '// HIGHLIGHT_JS',
      markedJs: '// MARKED_JS',
      tailwindJs: '// TAILWIND_JS',
      tailwindFormsJs: '// TAILWIND_FORMS_JS',
      fontBase64: 'FONT_BASE64',
    );

    // 所有占位引用都应被替换
    expect(html.contains('href="highlight.min.css"'), isFalse);
    expect(html.contains('src="highlight.min.js"'), isFalse);
    expect(html.contains('src="tailwind.js"'), isFalse);
    expect(html.contains('src="tailwind.forms.js"'), isFalse);
    expect(html.contains('src="marked.min.js"'), isFalse);
    expect(html.contains('JetBrainsMono-Regular.woff2'), isFalse);

    // 资源内容被内联
    expect(html.contains('/* CSS */'), isTrue);
    expect(html.contains('// HIGHLIGHT_JS'), isTrue);
    expect(html.contains('// MARKED_JS'), isTrue);
    expect(html.contains('// TAILWIND_JS'), isTrue);
    expect(html.contains('// TAILWIND_FORMS_JS'), isTrue);
    expect(html.contains('url(data:font/woff2;base64,FONT_BASE64)'), isTrue);
  });

  test('encodeJsStringLiteral 转义特殊字符', () {
    expect(encodeJsStringLiteral('a"b'), '"a\\"b"');
    expect(encodeJsStringLiteral('a\nb'), '"a\\nb"');
    expect(encodeJsStringLiteral('a\\b'), '"a\\\\b"');
    expect(
      encodeJsStringLiteral('a\u2028b'),
      '"a\\u2028b"',
    );
  });

  test('buildRenderScript 选择正确的渲染函数', () {
    expect(
      buildRenderScript('# Hi', isMarkdown: true),
      'window.renderMarkdown("# Hi");',
    );
    expect(
      buildRenderScript('<p>Hi</p>', isMarkdown: false),
      'window.renderHTML("<p>Hi</p>");',
    );
  });

  test('buildSetDarkScript 生成主题切换语句', () {
    expect(buildSetDarkScript(true), 'window.setPreviewDark(true);');
    expect(buildSetDarkScript(false), 'window.setPreviewDark(false);');
  });

  test('buildPreviewDocument 烘焙暗色 class、内容与滚动恢复', () {
    const base = '<html><head></head><body><div id="content"></div></body></html>';
    final doc = buildPreviewDocument(
      baseHtml: base,
      content: '# Hi',
      dark: true,
      initialScrollFraction: 0.5,
    );
    expect(doc.startsWith('<html class="dark">'), isTrue);
    expect(doc.contains('window.renderMarkdown("# Hi");'), isTrue);
    expect(doc.contains('window.__scrollToFraction(0.5);'), isTrue);

    // 亮色且不恢复滚动时不应注入对应内容
    final light = buildPreviewDocument(baseHtml: base, content: '# Hi');
    expect(light.contains('class="dark"'), isFalse);
    expect(light.contains('__scrollToFraction'), isFalse);
  });

  test('真实资产构建 HTML（内联字体与脚本）', () async {
    final html = await loadMarkdownPreviewHtml();

    // 资源占位应全部被替换
    expect(html.contains('src="marked.min.js"'), isFalse);
    expect(html.contains('JetBrainsMono-Regular.woff2'), isFalse);
    // 渲染 API 与库内容应存在
    expect(html.contains('window.renderMarkdown'), isTrue);
    expect(html.contains('marked.parse'), isTrue);
    expect(html.contains('data:font/woff2;base64,'), isTrue);
    // 暗色模式由 Flutter 显式驱动（html.dark 静态排版覆写 + setPreviewDark）
    expect(html.contains('html.dark .prose'), isTrue);
    expect(html.contains('window.setPreviewDark'), isTrue);
    // 不再以媒体查询作为暗色开关，也没有失效的 JS 配置块
    expect(html.contains("darkMode: 'media'"), isFalse);
    expect(html.contains('tailwind.config ='), isFalse);
    // 滚动同步辅助
    expect(html.contains('window.__scrollToFraction'), isTrue);
    expect(html.contains('PreviewScroll'), isTrue);
  });
}
