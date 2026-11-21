import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../data/diary_api.dart';

/// 日记列表状态管理。
class DiaryListNotifier extends PagedNotifier<Diary> {
  DiarySort _sort = DiarySort.createTimeDesc;

  /// 当前排序。
  DiarySort get sort => _sort;

  @override
  Future<Pager<Diary>> fetchPage(int page) {
    return ref.read(diaryApiProvider).diaries(page: page, size: 10, sort: _sort);
  }

  /// 切换排序。
  Future<void> setSort(DiarySort sort) async {
    _sort = sort;
    await reload();
  }
}

/// 日记列表提供者。
final diaryListProvider =
    AsyncNotifierProvider<DiaryListNotifier, PagedState<Diary>>(
  DiaryListNotifier.new,
);
