/// 非 IO 平台（Web 端）的占位实现：没有文件系统概念。
///
/// Web 端 dio.download 会直接触发浏览器下载，返回值不会被真正使用。
String systemTempPath() => '.';
