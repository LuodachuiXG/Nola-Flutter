/// 规范化服务器地址，用于按服务器隔离本地保存的数据。
///
/// 统一去空白、小写协议与主机、去结尾斜杠；解析失败时返回原文。
String normalizeServerUrl(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return text;
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final port = uri.hasPort ? ':${uri.port}' : '';
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  return '$scheme://$host$port$path';
}
