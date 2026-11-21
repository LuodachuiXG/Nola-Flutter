import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../data/link_api.dart';

/// 友情链接列表状态管理。
class LinkListNotifier extends PagedNotifier<Link> {
  LinkSort _sort = LinkSort.priorityDesc;

  /// 当前排序。
  LinkSort get sort => _sort;

  @override
  Future<Pager<Link>> fetchPage(int page) {
    return ref.read(linkApiProvider).links(page: page, size: 10, sort: _sort);
  }

  /// 切换排序。
  Future<void> setSort(LinkSort sort) async {
    _sort = sort;
    await reload();
  }
}

/// 友情链接列表提供者。
final linkListProvider =
    AsyncNotifierProvider<LinkListNotifier, PagedState<Link>>(
  LinkListNotifier.new,
);
