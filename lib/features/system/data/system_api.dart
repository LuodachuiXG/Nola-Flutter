import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/system_models.dart';
import '../../../core/network/api_client.dart';

/// 系统管理 API（操作记录与访问日志）。
class SystemApi {
  SystemApi(this._client);

  final ApiClient _client;

  // ==================== 操作记录 ====================

  /// 分页获取操作记录。
  Future<Pager<Operation>> operations({
    required int page,
    required int size,
    CommentSort? sort,
  }) async {
    return await _client.get<Pager<Operation>>(
      '/admin/operation',
      query: {
        'page': page,
        'size': size,
        if (sort != null) 'sort': sort.json,
      },
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Operation.fromJson,
      ),
    ) as Pager<Operation>;
  }

  /// 删除操作记录。
  Future<bool> deleteOperations(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/operation',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除全部操作记录。
  Future<bool> deleteAllOperations() async {
    return await _client.delete<bool>(
          '/admin/operation/all',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除指定时间以前的操作记录。
  Future<bool> deleteOperationsBefore(int time) async {
    return await _client.delete<bool>(
          '/admin/operation/before/$time',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  // ==================== 访问日志 ====================

  /// 分页获取访问日志。
  Future<Pager<AccessLog>> accessLogs({
    required int page,
    required int size,
  }) async {
    return await _client.get<Pager<AccessLog>>(
      '/admin/access-log',
      query: {'page': page, 'size': size},
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        AccessLog.fromJson,
      ),
    ) as Pager<AccessLog>;
  }

  /// 获取访问日志总数。
  Future<int> accessLogCount() async {
    final data = await _client.get<Object?>(
      '/admin/access-log/count',
      parse: (data) => data,
    );
    return (data is num) ? data.toInt() : 0;
  }

  /// 批量删除访问日志。
  Future<bool> deleteAccessLogs(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/access-log',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除全部访问日志。
  Future<bool> deleteAllAccessLogs() async {
    return await _client.delete<bool>(
          '/admin/access-log/all',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除指定时间以前的访问日志。
  Future<bool> deleteAccessLogsBefore(int time) async {
    return await _client.delete<bool>(
          '/admin/access-log/before/$time',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [SystemApi] 提供者。
final systemApiProvider = Provider<SystemApi>((ref) {
  return SystemApi(ref.watch(apiClientProvider));
});
