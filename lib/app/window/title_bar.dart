/// 桌面端窗口支持：隐藏系统标题栏，改为 Flutter 自绘标题栏。
///
/// 通过条件导入区分平台：Web 端走 [title_bar_stub]（空实现），
/// IO 平台走 [title_bar_io]（内部再按 Windows / Linux 判断是否生效）。
library;

export 'title_bar_stub.dart' if (dart.library.io) 'title_bar_io.dart';
