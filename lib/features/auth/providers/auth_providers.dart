import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/network/auth_events.dart';
import '../../../core/storage/local_storage.dart';
import '../data/auth_api.dart';

/// 会话控制器：管理登录令牌与用户信息。
///
/// 启动时从本地存储恢复会话；登录、登出、修改资料后同步更新
/// 本地持久化数据；收到 401 事件（登录过期）时自动登出。
class SessionController extends Notifier<UserInfo?> {
  @override
  UserInfo? build() {
    // 登录过期事件：清空本地会话（路由重定向由 go_router 完成）
    final subscription = AuthEvents.stream.listen((_) {
      _clearSession();
    });
    ref.onDispose(subscription.cancel);

    // 会话必须常驻，不随页面销毁
    ref.keepAlive();

    final storage = ref.watch(localStorageProvider);
    final token = storage.token;
    final userJson = storage.user;
    if (token == null || token.isEmpty || userJson == null) return null;
    return UserInfo.fromJson(userJson).copyWith(token: token);
  }

  /// 登录。
  Future<void> login(String username, String password) async {
    final api = ref.read(authApiProvider);
    final storage = ref.read(localStorageProvider);
    final user = await api.login(username, password);

    await storage.setToken(user.token);
    await storage.setUser(user.toJson());
    state = user;
  }

  /// 登出。
  ///
  /// [notifyServer] 为 true 时调用后端注销接口。
  Future<void> logout({bool notifyServer = true}) async {
    if (notifyServer) {
      try {
        await ref.read(authApiProvider).logout();
      } catch (_) {
        // 服务端注销失败不影响本地登出
      }
    }
    await _clearSession();
  }

  /// 修改用户资料后刷新本地会话中的用户信息。
  Future<void> refreshUserInfo() async {
    try {
      final user = await ref.read(authApiProvider).userInfo();
      if (user == null) return;
      final storage = ref.read(localStorageProvider);
      await storage.setUser(user.copyWith(token: state?.token).toJson());
      state = user.copyWith(token: state?.token);
    } catch (_) {
      // 拉取失败保持当前会话不变
    }
  }

  Future<void> _clearSession() async {
    final storage = ref.read(localStorageProvider);
    await storage.setToken(null);
    await storage.setUser(null);
    state = null;
  }
}

/// 会话提供者：值不为 null 表示已登录。
final sessionProvider =
    NotifierProvider<SessionController, UserInfo?>(SessionController.new);

/// 当前是否已登录。
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});
