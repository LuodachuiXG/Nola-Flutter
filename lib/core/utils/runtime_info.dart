/// 运行时系统 / Dart 版本信息：条件导入区分平台。
///
/// Web 端没有 dart:io（导入会导致 Web 编译失败），走 stub 返回 null；
/// IO 平台走 io 实现读取 `Platform` 信息。
library;

export 'runtime_info_stub.dart' if (dart.library.io) 'runtime_info_io.dart';
