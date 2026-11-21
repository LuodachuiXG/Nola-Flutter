import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/local_storage.dart';
import 'api_exception.dart';
import 'auth_events.dart';

/// 统一 API 客户端。
///
/// 封装 dio：动态注入服务器地址与 Bearer Token，解析 Nola 统一响应
/// `{code, errMsg, data}`，成功（code == 200）时返回 `data`，
/// 失败时抛出 [ApiException]；401 会同步发出登录过期事件。
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  /// GET 请求。
  Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T? Function(Object? data) parse,
  }) async {
    final data = await _send<T>(() => dio.get<Object?>(path, queryParameters: query));
    return parse(data);
  }

  /// POST 请求（JSON 请求体）。
  Future<T?> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T? Function(Object? data) parse,
  }) async {
    final data = await _send<T>(
      () => dio.post<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: _jsonBodyOptions(body),
      ),
    );
    return parse(data);
  }

  /// PUT 请求（JSON 请求体）。
  Future<T?> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T? Function(Object? data) parse,
  }) async {
    final data = await _send<T>(
      () => dio.put<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: _jsonBodyOptions(body),
      ),
    );
    return parse(data);
  }

  /// DELETE 请求（JSON 请求体）。
  ///
  /// 注意：后端批量删除接口的请求体是裸 JSON 数组（如 `[1, 2]`）。
  /// dio 会把 `List<int>` 当作原始字节而不自动推断 Content-Type，
  /// 导致后端无法按 JSON 解析（报“请求参数不匹配”），
  /// 因此这里显式声明 `application/json`。
  Future<T?> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T? Function(Object? data) parse,
  }) async {
    final data = await _send<T>(
      () => dio.delete<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: _jsonBodyOptions(body),
      ),
    );
    return parse(data);
  }

  /// 为 JSON 请求体显式声明 Content-Type。
  ///
  /// dio 的 ImplyContentTypeInterceptor 无法为 `List<int>` 等类型
  /// 推断默认 Content-Type；不声明时请求体不会被 jsonEncode，
  /// 后端将收到无法解析的请求体。
  static Options? _jsonBodyOptions(Object? body) {
    if (body == null || body is FormData || body is Stream) return null;
    return Options(contentType: Headers.jsonContentType);
  }

  /// 上传文件（multipart/form-data）。
  ///
  /// [fileName] 与 [fileBytes] 来自文件选择器；[fields] 为附加表单字段。
  Future<T?> upload<T>(
    String path, {
    required String fileName,
    required List<int> fileBytes,
    Map<String, String>? fields,
    required T? Function(Object? data) parse,
  }) async {
    final form = FormData.fromMap({
      ...?fields,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final data = await _send<T>(
      () => dio.post<Object?>(path, data: form),
      receiveTimeout: null, // 上传可能较慢，不限制响应超时
    );
    return parse(data);
  }

  /// 上传多个文件（multipart/form-data），用于备份导入。
  ///
  /// [files] 的键为文件名，值为文件字节内容。
  Future<T?> uploadFiles<T>(
    String path, {
    required Map<String, List<int>> files,
    required T? Function(Object? data) parse,
  }) async {
    final form = FormData();
    files.forEach((name, bytes) {
      form.files.add(
        MapEntry('file', MultipartFile.fromBytes(bytes, filename: name)),
      );
    });
    final data = await _send<T>(
      () => dio.post<Object?>(path, data: form),
      receiveTimeout: null,
    );
    return parse(data);
  }

  /// 下载文件到本地路径。
  Future<String> download(String path, String savePath) async {
    try {
      await dio.download(path, savePath);
      return savePath;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// 统一发送请求并解包响应。
  Future<Object?> _send<T>(
    Future<Response<Object?>> Function() request, {
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is! Map) {
        return null;
      }
      return body['data'];
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// 将 dio 异常转换为 [ApiException]。
  ApiException _mapDioException(DioException e) {
    // 响应拦截器抛出的业务异常直接透传
    final inner = e.error;
    if (inner is ApiException) {
      if (inner.isUnauthorized) {
        AuthEvents.emitUnauthorized();
      }
      return inner;
    }

    final response = e.response;
    if (response != null) {
      final body = response.data;
      int code = response.statusCode ?? 500;
      String message = response.statusMessage ?? '请求失败';

      // 业务码优先于 HTTP 状态码
      if (body is Map && body['code'] is int) {
        code = body['code'] as int;
        final errMsg = body['errMsg'];
        if (errMsg is String && errMsg.isNotEmpty) message = errMsg;
      } else if (body is Map && body['errMsg'] is String) {
        message = body['errMsg'] as String;
      }

      if (code == 401) {
        AuthEvents.emitUnauthorized();
        return ApiException(401, message);
      }
      return ApiException(code, message);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(0, '请求超时，请检查网络或服务器地址');
      case DioExceptionType.connectionError:
        return ApiException(0, '无法连接服务器，请检查网络或服务器地址');
      case DioExceptionType.cancel:
        return ApiException(0, '请求已取消');
      default:
        return ApiException(0, '网络异常：${e.message ?? '未知错误'}');
    }
  }
}

/// [ApiClient] 的 Riverpod 提供者。
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: kConnectTimeout,
      receiveTimeout: kReceiveTimeout,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // 动态拼接服务器地址，支持在登录页修改后立即生效
        final base = storage.serverUrl;
        options.baseUrl = base.endsWith('/')
            ? base.substring(0, base.length - 1)
            : base;

        final token = storage.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 解包 Nola 统一响应结构 {code, errMsg, data}
        final body = response.data;
        if (body is Map && body['code'] is int) {
          final code = body['code'] as int;
          if (code != 200) {
            final errMsg =
                (body['errMsg'] as String?) ?? '请求失败（$code）';
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: ApiException(code, errMsg),
              ),
              true,
            );
            return;
          }
        }
        handler.next(response);
      },
    ),
  );

  return ApiClient(dio);
});
