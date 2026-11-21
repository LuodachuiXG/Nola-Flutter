/// 接口业务异常。
///
/// 由 [ApiClient] 统一抛出：包含后端返回的 `code` 与 `errMsg`，
/// 或网络层的错误码（code 为 0 时表示无法连接服务器等本地网络错误）。
class ApiException implements Exception {
  ApiException(this.code, this.message);

  /// 后端业务码（通常与 HTTP 状态码一致），本地网络错误为 0。
  final int code;

  /// 错误描述。
  final String message;

  /// 是否为登录过期（401）。
  bool get isUnauthorized => code == 401;

  @override
  String toString() => message;
}
