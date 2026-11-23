import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';

/// 账号密码校验。
///
/// 使用独立 dio 请求，不经过全局 API 拦截器：设置页输入错误密码时
/// 不会触发登录过期事件，避免把当前会话误登出。
class AccountVerifier {
  const AccountVerifier({this.createDio = _defaultDio});

  /// 创建独立请求用的 dio（测试可注入替换）。
  final Dio Function() createDio;

  static Dio _defaultDio() => Dio(
        BaseOptions(
          connectTimeout: kConnectTimeout,
          receiveTimeout: kReceiveTimeout,
        ),
      );

  Future<void> verify({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final trimmed = serverUrl.trim();
    final base = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final dio = createDio();
    try {
      final response = await dio.post<Object?>(
        '$base/admin/user/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.jsonContentType),
      );
      _ensureSuccess(response.data);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body == null) {
        throw ApiException(0, '无法连接服务器，请检查网络或服务器地址');
      }
      _ensureSuccess(body);
    }
  }

  void _ensureSuccess(Object? body) {
    if (body is Map && body['code'] == 200) return;
    final code = body is Map && body['code'] is int ? body['code'] as int : 0;
    final message = body is Map && body['errMsg'] is String
        ? body['errMsg'] as String
        : '密码校验失败，请确认后重试';
    throw ApiException(code, message);
  }
}

/// [AccountVerifier] 提供者。
final accountVerifierProvider = Provider<AccountVerifier>(
  (ref) => const AccountVerifier(),
);
