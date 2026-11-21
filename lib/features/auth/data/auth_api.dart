import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/blog_models.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';

/// 认证与账号 API。
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// 管理员登录，成功返回带 Token 的用户信息。
  Future<UserInfo> login(String username, String password) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/user/login',
      body: {'username': username, 'password': password},
      parse: _requireMap,
    );
    if (data == null) {
      throw StateError('登录响应数据缺失');
    }
    return UserInfo.fromJson(data);
  }

  /// 获取当前登录用户信息。
  Future<UserInfo?> userInfo() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/user',
      parse: _optionalMap,
    );
    return data == null ? null : UserInfo.fromJson(data);
  }

  /// 修改当前登录用户信息。
  Future<bool> updateUserInfo(UserInfoRequest request) async {
    return await _client.put<bool>(
          '/admin/user',
          body: request.toJson(),
          parse: _optionalBool,
        ) ??
        false;
  }

  /// 修改当前登录用户密码。
  Future<bool> updatePassword(String password) async {
    return await _client.put<bool>(
          '/admin/user/password',
          body: {'password': password},
          parse: _optionalBool,
        ) ??
        false;
  }

  /// 注销登录。
  Future<bool> logout() async {
    return await _client.post<bool>(
          '/admin/user/logout',
          parse: _optionalBool,
        ) ??
        false;
  }

  /// 获取博客信息（公开接口），博客未初始化时返回 null。
  Future<BlogInfo?> blogInfo() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/api/config/blog',
      parse: _optionalMap,
    );
    return data == null ? null : BlogInfo.fromJson(data);
  }

  /// 初始化博客。
  Future<bool> initBlog({
    required String title,
    String? subtitle,
  }) async {
    return await _client.post<bool>(
          '/admin/config/blog',
          body: BlogInfo.initJson(title: title, subtitle: subtitle),
          parse: _optionalBool,
        ) ??
        false;
  }

  /// 初始化管理员。
  Future<bool> initAdmin({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) async {
    return await _client.post<bool>(
          '/admin/config/blog/admin',
          body: {
            'username': username,
            'displayName': displayName,
            'email': email,
            'password': password,
          },
          parse: _optionalBool,
        ) ??
        false;
  }
}

Map<String, dynamic>? _optionalMap(Object? data) =>
    data == null ? null : Map<String, dynamic>.from(data as Map);

Map<String, dynamic> _requireMap(Object? data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('接口返回数据格式错误');
}

bool _optionalBool(Object? data) => data is bool ? data : false;

/// [AuthApi] 的 Riverpod 提供者。
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});
