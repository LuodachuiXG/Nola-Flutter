import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/paged_notifier.dart';
import 'async_value_widget.dart';

/// 分页列表通用视图。
///
/// 集成下拉刷新、触底自动加载更多、空态与加载更多错误重试。
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.header,
    this.noItemsMessage = '暂无数据',
    this.emptyIcon = Icons.inbox_outlined,
    this.padding,
    this.scrollController,
  });

  /// 分页状态。
  final AsyncValue<PagedState<T>> value;

  /// 下拉刷新回调。
  final Future<void> Function() onRefresh;

  /// 触底加载更多回调。
  final Future<void> Function() onLoadMore;

  /// 列表项构建器。
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 列表头部（随列表滚动）。
  final Widget? header;

  /// 空数据提示文案。
  final String noItemsMessage;

  /// 空数据图标。
  final IconData emptyIcon;

  /// 列表内边距。
  final EdgeInsetsGeometry? padding;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<PagedState<T>>(
      value: value,
      // 首屏加载失败时提供重试入口（复用下拉刷新逻辑）
      error: (context, error) =>
          ErrorPlaceholder(message: '$error', onRetry: onRefresh),
      builder: (context, state) {
        final itemCount = state.items.length;
        final hasHeader = header != null;
        final emptyView = LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyPlaceholder(icon: emptyIcon, message: noItemsMessage),
            ),
          ),
        );

        final listView = ListView.builder(
          controller: scrollController,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: itemCount + (hasHeader ? 1 : 0) + 1,
          itemBuilder: (context, index) {
            // 头部视图
            if (hasHeader && index == 0) {
              return header!;
            }

            final itemIndex = index - (hasHeader ? 1 : 0);
            if (itemIndex < itemCount) {
              return itemBuilder(context, state.items[itemIndex]);
            }

            // 底部加载更多
            return _Footer(state: state, onLoadMore: onLoadMore);
          },
        );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: itemCount == 0 ? emptyView : listView,
        );
      },
    );
  }
}

/// 底部加载更多视图。
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final PagedState<dynamic> state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: FilledButton.tonalIcon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }

    if (state.loadingMore || state.hasMore) {
      // 还有下一页时，底部滑入视野自动触发加载
      if (state.hasMore && !state.loadingMore) {
        scheduleMicrotask(onLoadMore);
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          '没有更多了',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}
