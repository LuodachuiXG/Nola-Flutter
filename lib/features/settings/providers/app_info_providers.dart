import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/utils/runtime_info.dart';

/// 应用版本与当前构建信息。
class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.buildMode,
    required this.platform,
    this.osVersion,
    this.dartVersion,
  });

  /// 版本号（pubspec `version` 中 `+` 之前的部分）。
  final String version;

  /// 构建号（pubspec `version` 中 `+` 之后的部分）。
  final String buildNumber;

  /// 构建模式：Debug / Profile / Release。
  final String buildMode;

  /// 运行平台，含 CPU 架构（Web 端仅显示 Web）。
  final String platform;

  /// 操作系统版本描述，Web 端为 null。
  final String? osVersion;

  /// Dart 运行时版本，Web 端为 null。
  final String? dartVersion;

  /// `0.0.1 (1)` 形式的版本展示。
  String get versionLabel =>
      buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

/// 应用版本与构建信息（运行时读取一次，进程内缓存）。
final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final package = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    version: package.version,
    buildNumber: package.buildNumber,
    buildMode: kReleaseMode
        ? 'Release'
        : kProfileMode
            ? 'Profile'
            : 'Debug',
    platform: _platformLabel(),
    osVersion: operatingSystemVersion(),
    dartVersion: dartRuntimeVersion(),
  );
});

/// 运行平台展示名称，IO 平台附带 CPU 架构。
String _platformLabel() {
  if (kIsWeb) return 'Web';
  final name = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  final arch = cpuArchitecture();
  return arch == null ? name : '$name · $arch';
}
