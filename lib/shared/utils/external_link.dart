import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/dialogs.dart';

/// 用系统浏览器打开外部链接，失败时提示，避免点击无响应。
///
/// 缺少协议头时按 https 补全（如 `example.com` → `https://example.com`）。
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = _normalizeUrl(url);
  if (uri == null) {
    if (context.mounted) showGlobalSnack('链接格式无效：$url', error: true);
    return;
  }
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!launched && context.mounted) {
    showGlobalSnack('无法打开链接：$url', error: true);
  }
}

Uri? _normalizeUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final parsed = Uri.tryParse(text);
  if (parsed == null) return null;
  if (parsed.hasScheme) return parsed;
  return Uri.tryParse('https://$text');
}
