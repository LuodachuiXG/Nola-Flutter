/// 非 IO 平台（Web 端）的占位实现：无法读取原生系统与 Dart VM 信息。
library;

/// 操作系统版本描述（Web 端无）。
String? operatingSystemVersion() => null;

/// Dart 运行时版本号（Web 端无）。
String? dartRuntimeVersion() => null;

/// CPU 架构（Web 端无）。
String? cpuArchitecture() => null;
