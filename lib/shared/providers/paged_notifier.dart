import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/common.dart';

/// 分页列表通用状态。
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalData,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;

  /// 已加载的最后一页页码。
  final int page;
  final int totalPages;
  final int totalData;

  /// 是否正在加载下一页。
  final bool loadingMore;

  /// 加载下一页失败的错误信息。
  final String? loadMoreError;

  /// 是否还有更多数据。
  bool get hasMore => page < totalPages;

  factory PagedState.from(Pager<T> pager) => PagedState(
        items: pager.data,
        page: pager.page,
        totalPages: pager.totalPages,
        totalData: pager.totalData,
      );

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    int? totalPages,
    int? totalData,
    bool? loadingMore,
    String? loadMoreError,
  }) =>
      PagedState(
        items: items ?? this.items,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        totalData: totalData ?? this.totalData,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// 分页列表通用状态管理基类。
///
/// 子类实现 [fetchPage] 提供按页取数逻辑，即可获得
/// 首屏加载、上拉加载更多、下拉刷新能力；筛选条件由子类
/// 以字段形式保存，修改后调用 [reload] 重新加载第一页。
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  /// 拉取一页数据。
  Future<Pager<T>> fetchPage(int page);

  @override
  Future<PagedState<T>> build() async {
    final pager = await fetchPage(1);
    return PagedState.from(pager);
  }

  /// 加载下一页。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreError: null));
    try {
      final pager = await fetchPage(current.page + 1);
      state = AsyncData(
        PagedState.from(pager).copyWith(
          items: [...current.items, ...pager.data],
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          loadingMore: false,
          loadMoreError: '$error',
        ),
      );
    }
  }

  /// 下拉刷新：重新加载第一页，保留当前筛选条件。
  ///
  /// 失败时保留旧数据并向调用方抛出异常（由 UI 层提示）。
  Future<void> refresh() async {
    final previous = state.value;
    try {
      final pager = await fetchPage(1);
      state = AsyncData(PagedState.from(pager));
    } catch (error) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  /// 应用新筛选条件后重载第一页（失败时保留旧数据并抛出异常）。
  Future<void> reload() async {
    final previous = state.value;
    try {
      final pager = await fetchPage(1);
      state = AsyncData(PagedState.from(pager));
    } catch (error) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }
}
