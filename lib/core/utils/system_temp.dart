/// 系统临时目录路径：条件导入区分平台。
///
/// Web 端没有 dart:io（导入会导致 Web 编译失败），走 stub 返回占位值；
/// IO 平台走 io 实现返回 `Directory.systemTemp.path`。
library;

export 'system_temp_stub.dart' if (dart.library.io) 'system_temp_io.dart';
