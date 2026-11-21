import 'dart:async';

/// 全局认证事件总线。
///
/// 网络层在收到 401（登录过期）时发出事件，会话控制器监听并执行登出。
class AuthEvents {
  AuthEvents._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// 认证事件流（登录过期时收到事件）。
  static Stream<void> get stream => _controller.stream;

  /// 发出登录过期事件。
  static void emitUnauthorized() {
    _controller.add(null);
  }

  /// 关闭事件总线（测试用）。
  static void close() {
    _controller.close();
  }
}
