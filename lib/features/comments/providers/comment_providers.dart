import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment.dart';
import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../data/comment_api.dart';

/// 评论筛选条件。
class CommentFilter {
  const CommentFilter({this.isPass, this.key, this.sort});

  final bool? isPass;
  final String? key;
  final CommentSort? sort;
}

/// 评论列表状态管理。
class CommentListNotifier extends PagedNotifier<Comment> {
  CommentFilter _filter = const CommentFilter(sort: CommentSort.createTimeDesc);

  /// 当前筛选条件。
  CommentFilter get filter => _filter;

  @override
  Future<Pager<Comment>> fetchPage(int page) {
    return ref.read(commentApiProvider).comments(
          page: page,
          size: 10,
          isPass: _filter.isPass,
          key: _filter.key,
          sort: _filter.sort,
          tree: true,
        );
  }

  /// 应用筛选。
  Future<void> applyFilter({
    bool? isPass,
    String? key,
    CommentSort? sort,
  }) async {
    _filter = CommentFilter(isPass: isPass, key: key, sort: sort);
    await reload();
  }
}

/// 评论列表提供者。
final commentListProvider =
    AsyncNotifierProvider<CommentListNotifier, PagedState<Comment>>(
  CommentListNotifier.new,
);
