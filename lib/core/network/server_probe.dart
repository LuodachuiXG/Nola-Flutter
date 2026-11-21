import 'package:dio/dio.dart';

/// 服务器连接探测结果。
class ServerProbeResult {
  const ServerProbeResult({
    required this.reachable,
    required this.isNola,
    required this.available,
    required this.message,
  });

  /// 是否能建立 HTTP 连接并收到响应。
  final bool reachable;

  /// 响应是否符合 Nola 协议（统一响应结构 `{code, errMsg, data}`）。
  final bool isNola;

  /// Nola 服务是否可用（isNola 且 code == 200）。
  final bool available;

  /// 供界面展示的结果说明。
  final String message;

  /// 探测成功。
  bool get success => available;
}

/// 服务器连接探测工具。
///
/// 通过请求公开接口 `GET /api/config/blog` 验证：
/// 1. 服务器是否可达；
/// 2. 响应是否为 Nola 统一响应结构（确认是 Nola 服务）；
/// 3. `code == 200`（服务可用，博客未初始化时 data 为 null 也算可用）。
class ServerProbe {
  ServerProbe._();

  /// 探测超时时长。
  static const Duration _timeout = Duration(seconds: 6);

  /// 探测指定服务器地址。
  ///
  /// 使用独立的 dio 实例（不携带 Token、不经过业务拦截器），
  /// 以便区分「无法连接」「非 Nola 服务」「服务异常」等不同结果。
  static Future<ServerProbeResult> probe(String serverUrl) async {
    final base = serverUrl.trim();
    final dio = Dio(
      BaseOptions(
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        // 避免目标服务器返回非 200 时抛异常
        validateStatus: (_) => true,
      ),
    );

    final Response response;
    try {
      response = await dio.get<Object?>(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}'
        '/api/config/blog',
        options: Options(responseType: ResponseType.json),
      );
    } on DioException catch (error) {
      return ServerProbeResult(
        reachable: false,
        isNola: false,
        available: false,
        message: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            '连接超时，请检查地址或网络',
          _ => '无法连接服务器，请检查地址或网络',
        },
      );
    } catch (_) {
      return const ServerProbeResult(
        reachable: false,
        isNola: false,
        available: false,
        message: '无法连接服务器，请检查地址或网络',
      );
    }

    final body = response.data;
    // 判断响应是否为 Nola 统一响应结构
    if (body is! Map || body['code'] is! int) {
      return ServerProbeResult(
        reachable: true,
        isNola: false,
        available: false,
        message: '已连接，但目标不是 Nola 服务',
      );
    }

    final code = body['code'] as int;
    if (code != 200) {
      return ServerProbeResult(
        reachable: true,
        isNola: true,
        available: false,
        message: 'Nola 服务响应异常（$code）',
      );
    }

    return const ServerProbeResult(
      reachable: true,
      isNola: true,
      available: true,
      message: '连接成功，Nola 服务可用',
    );
  }
}
