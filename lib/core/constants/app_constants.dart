/// 应用全局常量。
library;

/// 默认服务器地址（Nola 后端 Ktor 默认端口 8098）。
const String kDefaultServerUrl = 'http://127.0.0.1:8098';

/// 连接超时时长。
const Duration kConnectTimeout = Duration(seconds: 10);

/// 响应超时时长。
const Duration kReceiveTimeout = Duration(seconds: 30);

/// 列表分页默认每页条数。
const int kDefaultPageSize = 10;

/// 本地存储键名。
final class StorageKeys {
  const StorageKeys._();

  /// 服务器地址。
  static const String serverUrl = 'nola.server.url';

  /// 登录令牌。
  static const String token = 'nola.auth.token';

  /// 登录用户信息（JSON 字符串）。
  static const String user = 'nola.auth.user';

  /// 主题模式（system / light / dark）。
  static const String themeMode = 'nola.app.themeMode';

  /// 主题色（十六进制 RGB，不含 #）。
  static const String seedColor = 'nola.app.seedColor';

  /// 已保存的服务器地址列表（JSON 数组）。
  static const String savedServers = 'nola.server.saved';
}
