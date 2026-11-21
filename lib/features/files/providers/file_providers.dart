import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/file_models.dart';
import '../../../core/models/common.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../data/file_api.dart';

/// 文件筛选条件。
class FileFilter {
  const FileFilter({this.mode, this.groupId, this.key, this.sort});

  final FileStorageMode? mode;
  final int? groupId;
  final String? key;
  final FileSort? sort;
}

/// 文件列表状态管理。
class FileListNotifier extends PagedNotifier<FileItem> {
  FileFilter _filter = const FileFilter(sort: FileSort.createTimeDesc);

  /// 当前筛选条件。
  FileFilter get filter => _filter;

  @override
  Future<Pager<FileItem>> fetchPage(int page) {
    return ref.read(fileApiProvider).files(
          page: page,
          size: 20,
          mode: _filter.mode,
          groupId: _filter.groupId,
          key: _filter.key,
          sort: _filter.sort,
        );
  }

  /// 应用筛选。
  Future<void> applyFilter({
    FileStorageMode? mode,
    int? groupId,
    String? key,
    FileSort? sort,
  }) async {
    _filter = FileFilter(mode: mode, groupId: groupId, key: key, sort: sort);
    await reload();
  }
}

/// 文件列表提供者。
final fileListProvider =
    AsyncNotifierProvider<FileListNotifier, PagedState<FileItem>>(
  FileListNotifier.new,
);

/// 文件组列表。
final fileGroupsProvider =
    FutureProvider.autoDispose<List<FileGroup>>((ref) {
  return ref.watch(fileApiProvider).groups();
});

/// 已配置的存储方式列表。
final storageModesProvider =
    FutureProvider.autoDispose<List<FileStorageMode>>((ref) {
  return ref.watch(fileApiProvider).modes();
});

/// 腾讯云 COS 配置。
final tencentCOSProvider =
    FutureProvider.autoDispose<TencentCOSConfig?>((ref) {
  return ref.watch(fileApiProvider).tencentCOS();
});
