import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/diary_api.dart';
import '../providers/diary_providers.dart';

/// 日记（日常）管理页。
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(diaryListProvider);
    final notifier = ref.read(diaryListProvider.notifier);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '日常',
        actions: [
          PopupMenuButton<DiarySort>(
            tooltip: '排序',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) async {
              try {
                await notifier.setSort(sort);
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            itemBuilder: (context) => [
              for (final sort in DiarySort.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      if (notifier.sort == sort)
                        const Icon(Icons.check, size: 16),
                      const SizedBox(width: 8),
                      Text(sort.label),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDiaryForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('写日记'),
      ),
      body: PagedListView<Diary>(
        value: listState,
        emptyIcon: Icons.edit_note_outlined,
        noItemsMessage: '还没有日记',
        onRefresh: () async {
          try {
            await notifier.refresh();
          } on ApiException catch (error) {
            if (context.mounted) showGlobalSnack( error.message, error: true);
          }
        },
        onLoadMore: () => notifier.loadMore(),
        itemBuilder: (context, diary) =>
            _DiaryTile(diary: diary, onEdit: () => _showDiaryForm(context, ref, diary: diary)),
      ),
    );
  }

  /// 日记编辑弹层。
  void _showDiaryForm(
    BuildContext context,
    WidgetRef ref, {
    Diary? diary,
  }) {
    final contentController = TextEditingController(text: diary?.content ?? '');
    showFormSheet(
      context,
      title: diary == null ? '写日记' : '修改日记',
      saveText: '保存',
      builder: (context) => TextFormField(
        controller: contentController,
        maxLines: 8,
        autofocus: diary == null,
        decoration: const InputDecoration(
          hintText: '记录点什么…（支持 Markdown）',
          alignLabelWithHint: true,
        ),
      ),
      onSave: () async {
        final content = contentController.text.trim();
        if (content.isEmpty) {
          showGlobalSnack( '日记内容不能为空', error: true);
          return false;
        }
        final api = ref.read(diaryApiProvider);
        try {
          if (diary == null) {
            await api.addDiary(content);
            showGlobalSnack( '日记已保存');
          } else {
            await api.updateDiary(diary.diaryId, content);
            showGlobalSnack( '日记已更新');
          }
          await ref.read(diaryListProvider.notifier).reload();
          return true;
        } on ApiException catch (error) {
          showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }
}

/// 日记列表项。
class _DiaryTile extends ConsumerWidget {
  const _DiaryTile({required this.diary, required this.onEdit});

  final Diary diary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(diaryApiProvider);
    final notifier = ref.read(diaryListProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diary.content,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatDateTime(diary.createTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (diary.lastModifyTime != null &&
                    diary.lastModifyTime != diary.createTime) ...[
                  const SizedBox(width: 8),
                  Text(
                    '修改于 ${formatDateTime(diary.lastModifyTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: '删除',
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: '删除日记',
                      content: '确定删除这条日记吗？',
                      danger: true,
                      confirmText: '删除',
                    );
                    if (!confirmed) return;
                    try {
                      await api.deleteDiaries([diary.diaryId]);
                      if (context.mounted) showGlobalSnack( '日记已删除');
                      await notifier.refresh();
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        showGlobalSnack( error.message, error: true);
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
