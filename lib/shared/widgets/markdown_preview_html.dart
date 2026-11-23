/// Markdown 预览 HTML 构建（纯字符串处理，无 Flutter 依赖）。
///
/// 资源与 Nola-Apple 项目的 `markdown.html` 保持一致：
/// marked 解析 Markdown、highlight.js 高亮代码、Tailwind prose 排版
/// （含暗色模式适配）与 JetBrains Mono 等宽字体。
///
/// 构建策略：将模板中引用的本地 CSS / JS / 字体全部内联为单文件 HTML，
/// 便于 WebView 通过 `loadHtmlString` 加载（无需相对路径资源）。
library;

import 'dart:convert';

/// 模板中的资源引用占位（与 Nola-Apple 的 markdown.html 一致）。
const String _linkCssTag = '<link rel="stylesheet" href="highlight.min.css">';
const String _scriptHighlightTag = '<script src="highlight.min.js"></script>';
const String _scriptTailwindTag = '<script src="tailwind.js"></script>';
const String _scriptTailwindFormsTag = '<script src="tailwind.forms.js"></script>';
const String _scriptMarkedTag = '<script src="marked.min.js"></script>';
const String _fontUrlLine =
    "src: url('JetBrainsMono-Regular.woff2') format('woff2');";

/// 构建自包含的预览 HTML。
///
/// [fontBase64] 为 JetBrains Mono woff2 字体的 Base64 内容，
/// 将以 data URI 形式内联，避免 WebView 加载相对路径资源。
String buildMarkdownHtml({
  required String template,
  required String css,
  required String highlightJs,
  required String markedJs,
  required String tailwindJs,
  required String tailwindFormsJs,
  required String fontBase64,
}) {
  return template
      .replaceFirst(_linkCssTag, '<style>\n$css\n</style>')
      .replaceFirst(_scriptHighlightTag, '<script>\n$highlightJs\n</script>')
      .replaceFirst(_scriptTailwindTag, '<script>\n$tailwindJs\n</script>')
      .replaceFirst(
        _scriptTailwindFormsTag,
        '<script>\n$tailwindFormsJs\n</script>',
      )
      .replaceFirst(_scriptMarkedTag, '<script>\n$markedJs\n</script>')
      .replaceFirst(
        _fontUrlLine,
        'src: url(data:font/woff2;base64,$fontBase64) format(\'woff2\');',
      );
}

/// 将文本编码为可安全内嵌的 JS 字符串字面量。
///
/// jsonEncode 会转义引号、反斜杠与换行；U+2028 / U+2029 在
/// JavaScript 字符串中合法但在 JSON 中未转义，需手动处理。
String encodeJsStringLiteral(String text) {
  return jsonEncode(text)
      .replaceAll('\u2028', '\\u2028')
      .replaceAll('\u2029', '\\u2029');
}

/// 构建切换预览主题（暗色 / 亮色）的 JS 语句。
///
/// 与模板中的 `window.setPreviewDark` 对应：通过 `<html>` 根节点的
/// `dark` class 驱动 Tailwind class 暗色模式（darkMode: 'class'），
/// 使 WebView 预览与 Flutter 的亮暗主题保持一致（含强制亮 / 暗场景）。
String buildSetDarkScript(bool dark) => 'window.setPreviewDark($dark);';

/// 基于缓存的自包含 HTML，烘焙出一份可直接加载的最终文档。
///
/// - [dark] 为 true 时给 `<html>` 挂上 `dark` class（解析期即生效，
///   不依赖 JS 桥，用于 macOS 等桥接不可信的环境）；
/// - [content] 以页面内嵌脚本渲染（同样不依赖 JS 桥）；
/// - [initialScrollFraction] 大于 0 时内嵌滚动恢复脚本。
String buildPreviewDocument({
  required String baseHtml,
  required String content,
  bool isMarkdown = true,
  bool dark = false,
  double initialScrollFraction = 0,
}) {
  var html = baseHtml;
  if (dark) {
    html = html.replaceFirst('<html>', '<html class="dark">');
  }
  // 标记主题已随文档烘焙，页面内的系统暗色回退不再生效
  html = html.replaceFirst(
    '<head>',
    '<head><script>window.__themeBaked=true;</script>',
  );
  final buffer = StringBuffer(buildRenderScript(content, isMarkdown: isMarkdown));
  if (initialScrollFraction > 0) {
    buffer.write('window.__scrollToFraction($initialScrollFraction);');
  }
  return html.replaceFirst('</body>', '<script>$buffer</script></body>');
}

/// 构建注入内容的 JS 语句。
///
/// [isMarkdown] 为 true 时走 Markdown 解析渲染，否则按 HTML 直出。
String buildRenderScript(String content, {bool isMarkdown = true}) {
  final function = isMarkdown ? 'window.renderMarkdown' : 'window.renderHTML';
  return '$function(${encodeJsStringLiteral(content)});';
}
