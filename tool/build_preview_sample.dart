/// 生成 Markdown 预览样例 HTML（用于浏览器人工验证渲染管线）。
///
/// 运行：dart run tool/build_preview_sample.dart
/// 输出：build/preview_sample.html
library;

import 'dart:convert';
import 'dart:io';

import 'package:nola/shared/widgets/markdown_preview_html.dart';

void main() {
  final root = Directory.current.path;
  String read(String path) => File('$root/assets/markdown/$path').readAsStringSync();
  String base64(String path) =>
      base64Encode(File('$root/assets/markdown/$path').readAsBytesSync());

  final html = buildMarkdownHtml(
    template: read('markdown.html'),
    css: read('highlight.min.css'),
    highlightJs: read('highlight.min.js'),
    markedJs: read('marked.min.js'),
    tailwindJs: read('tailwind.js'),
    tailwindFormsJs: read('tailwind.forms.js'),
    fontBase64: base64('JetBrainsMono-Regular.woff2'),
  );

  // 注入一段覆盖常见语法的样例文章，页面加载后自动渲染
  const sample = '''
# 欢迎使用 Nola

这是一段 **加粗**、*斜体* 与 `行内代码` 的示例，来自 [Nola](https://github.com/LuodachuiXG/Nola) 博客。

## 二级标题

- 列表项一
- 列表项二
  - 嵌套项

> 这是一段引用文字，用来测试排版效果。

### 代码高亮

```dart
void main() {
  final blog = 'Nola';
  print('Hello, \$blog!');
}
```

### 表格

| 功能 | 状态 |
| --- | --- |
| Markdown 渲染 | ✅ |
| 代码高亮 | ✅ |
| 暗色模式 | ✅ |

---

结束。谢谢阅读！
''';

  final output = html.replaceFirst(
    '</body>',
    '<script>window.renderMarkdown(${encodeJsStringLiteral(sample)});</script></body>',
  );

  File('$root/build/preview_sample.html')
      .writeAsStringSync(output, flush: true);
  stdout.writeln('已生成 build/preview_sample.html');
}
