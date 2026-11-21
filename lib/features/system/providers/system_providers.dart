import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/system_models.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../data/system_api.dart';

/// 操作记录列表状态管理。
class OperationListNotifier extends PagedNotifier<Operation> {
  CommentSort _sort = CommentSort.createTimeDesc;

  /// 当前排序。
  CommentSort get sort => _sort;

  @override
  Future<Pager<Operation>> fetchPage(int page) {
    return ref
        .read(systemApiProvider)
        .operations(page: page, size: 10, sort: _sort);
  }

  /// 切换排序。
  Future<void> setSort(CommentSort sort) async {
    _sort = sort;
    await reload();
  }
}

/// 操作记录列表提供者。
final operationListProvider =
    AsyncNotifierProvider<OperationListNotifier, PagedState<Operation>>(
  OperationListNotifier.new,
);

/// 访问日志列表状态管理。
class AccessLogListNotifier extends PagedNotifier<AccessLog> {
  @override
  Future<Pager<AccessLog>> fetchPage(int page) {
    return ref.read(systemApiProvider).accessLogs(page: page, size: 10);
  }
}

/// 访问日志列表提供者。
final accessLogListProvider =
    AsyncNotifierProvider<AccessLogListNotifier, PagedState<AccessLog>>(
  AccessLogListNotifier.new,
);
