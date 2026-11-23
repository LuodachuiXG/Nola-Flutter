import 'dart:io';

/// IO 平台的操作系统版本描述，如 `Version 27.0.1 (Build 26A434)`。
String? operatingSystemVersion() => Platform.operatingSystemVersion;

/// IO 平台的 Dart 运行时版本号，如 `3.13.5`。
String? dartRuntimeVersion() {
  final version = Platform.version;
  final match = RegExp(r'^\S+').firstMatch(version);
  return match?.group(0) ?? version;
}

/// CPU 架构，如 `arm64`。
///
/// `Platform.version` 末尾包含目标平台串（如 `macos_arm64`），
/// 解析不到时返回 null。
String? cpuArchitecture() {
  final match = RegExp(r'on "([^"]+)"').firstMatch(Platform.version);
  final target = match?.group(1);
  if (target == null) return null;
  final separator = target.indexOf('_');
  return separator < 0 ? null : target.substring(separator + 1);
}
