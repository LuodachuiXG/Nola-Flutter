/// 格式化工具：时间、文件大小、URL。
library;

import 'package:intl/intl.dart';

/// 格式化毫秒时间戳为 `yyyy-MM-dd HH:mm`。
String formatDateTime(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return '-';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

/// 格式化毫秒时间戳为 `yyyy-MM-dd`。
String formatDate(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return '-';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return DateFormat('yyyy-MM-dd').format(date);
}

/// 格式化字节数为人类可读大小。
String formatFileSize(int? bytes) {
  if (bytes == null || bytes < 0) return '-';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final text = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// 为相对路径拼接服务器地址，返回完整可访问 URL。
///
/// 后端本地存储的文件 URL 是相对路径（如 `/upload/img/1.jpg`），
/// 对象存储返回完整 URL 时原样返回。
String resolveFileUrl(String? url, String serverUrl) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
  return url.startsWith('/') ? '$base$url' : '$base/$url';
}

/// 将颜色十六进制字符串（如 `#3FB27F`）解析为 `0xFF3FB27F` 整数值。
int? parseHexColor(String? hex) {
  if (hex == null) return null;
  final text = hex.replaceFirst('#', '').trim();
  if (text.length == 6) {
    return int.tryParse('FF$text', radix: 16);
  }
  if (text.length == 8) {
    return int.tryParse(text, radix: 16);
  }
  return null;
}

/// 校验邮箱格式。
bool isValidEmail(String? email) =>
    email != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
