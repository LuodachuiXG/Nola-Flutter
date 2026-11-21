import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/comment_api.dart';
import '../providers/comment_providers.dart';

/// 评论管理页。
class CommentScreen extends ConsumerWidget {
  const CommentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(commentListProvider);
    final notifier = ref.read(commentListProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '评论',
        actions: [
          // 审核状态筛选
          PopupMenuButton<String>(
            tooltip: '筛选',
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (value) async {
              final isPass = value == 'all' ? null : value == 'passed';
              try {
                await notifier.applyFilter(
                  isPass: isPass,
                  key: notifier.filter.key,
                  sort: notifier.filter.sort,
                );
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    if (notifier.filter.isPass == null)
                      const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    const Text('全部'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'passed',
                child: Row(
                  children: [
                    if (notifier.filter.isPass == true)
                      const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    const Text('已通过'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    if (notifier.filter.isPass == false)
                      const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    const Text('待审核'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context, ref, notifier),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 排序切换
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  '时间${notifier.filter.sort == CommentSort.createTimeAsc ? '升序' : '降序'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final newSort =
                        notifier.filter.sort == CommentSort.createTimeAsc
                            ? CommentSort.createTimeDesc
                            : CommentSort.createTimeAsc;
                    try {
                      await notifier.applyFilter(
                        isPass: notifier.filter.isPass,
                        key: notifier.filter.key,
                        sort: newSort,
                      );
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        showGlobalSnack( error.message, error: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: const Text('切换排序'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<Comment>(
              value: listState,
              emptyIcon: Icons.mode_comment_outlined,
              noItemsMessage: '暂无评论',
              onRefresh: () async {
                try {
                  await notifier.refresh();
                } on ApiException catch (error) {
                  if (context.mounted) {
                    showGlobalSnack( error.message, error: true);
                  }
                }
              },
              onLoadMore: () => notifier.loadMore(),
              itemBuilder: (context, comment) => _CommentTile(
                comment: comment,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(
    BuildContext context,
    WidgetRef ref,
    CommentListNotifier notifier,
  ) {
    final controller = TextEditingController(text: notifier.filter.key ?? '');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索评论'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '评论内容关键字'),
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final key = controller.text.trim();
              Navigator.of(context).pop();
              try {
                await notifier.applyFilter(
                  isPass: notifier.filter.isPass,
                  key: key,
                  sort: notifier.filter.sort,
                );
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }
}

/// 评论列表项。
class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(commentApiProvider);
    final notifier = ref.read(commentListProvider.notifier);
    final children = comment.children ?? const <Comment>[];

    Future<void> mutate(Future<bool> Function() action, String message) async {
      try {
        await action();
        if (context.mounted) showGlobalSnack( message);
        await notifier.refresh();
      } on ApiException catch (error) {
        if (context.mounted) showGlobalSnack( error.message, error: true);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    comment.displayName.isNotEmpty
                        ? comment.displayName.characters.first
                        : '?',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(comment.displayName,
                    style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                if (comment.site != null && comment.site!.isNotEmpty)
                  Text(
                    comment.site!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const Spacer(),
                Text(
                  formatDateTime(comment.createTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: comment.isPass
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    comment.isPass ? '已通过' : '待审核',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: comment.isPass
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (comment.postTitle != null)
                  Text(
                    '文章：${comment.postTitle}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                Text(
                  '邮箱：${comment.email}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            // 子评论
            if (children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    for (final child in children)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: child.displayName,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (child.replyDisplayName != null)
                                    TextSpan(
                                      text:
                                          ' 回复 ${child.replyDisplayName}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  TextSpan(
                                    text:
                                        '：${child.content}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatDateTime(child.createTime),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => mutate(
                                    () => api.setCommentPass(
                                      [child.commentId],
                                      !child.isPass,
                                    ),
                                    child.isPass ? '已驳回' : '已通过',
                                  ),
                                  child: Text(
                                    child.isPass ? '驳回' : '通过',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final confirmed = await showConfirmDialog(
                                      context,
                                      title: '删除回复',
                                      content:
                                          '确定删除「${child.displayName}」的回复吗？',
                                      danger: true,
                                      confirmText: '删除',
                                    );
                                    if (!confirmed) return;
                                    await mutate(
                                      () => api
                                          .deleteComments([child.commentId]),
                                      '已删除',
                                    );
                                  },
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            // 主评论操作
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!comment.isPass)
                  FilledButton.tonal(
                    onPressed: () => mutate(
                      () => api.setCommentPass([comment.commentId], true),
                      '已通过审核',
                    ),
                    child: const Text('通过审核'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => mutate(
                      () => api.setCommentPass([comment.commentId], false),
                      '已驳回',
                    ),
                    child: const Text('驳回'),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      _showEditDialog(context, ref, api, notifier),
                  child: const Text('编辑'),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: '删除评论',
                      content: '删除评论将同时删除其所有回复，确定继续吗？',
                      danger: true,
                      confirmText: '删除',
                    );
                    if (!confirmed) return;
                    await mutate(
                      () => api.deleteComments([comment.commentId]),
                      '已删除',
                    );
                  },
                  child: Text(
                    '删除',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑评论内容。
  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    CommentApi api,
    CommentListNotifier notifier,
  ) {
    final contentController = TextEditingController(text: comment.content);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑评论'),
        content: TextField(
          controller: contentController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '评论内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final content = contentController.text.trim();
              if (content.isEmpty) return;
              Navigator.of(dialogContext).pop();
              try {
                await api.updateComment(CommentUpdateRequest(
                  commentId: comment.commentId,
                  content: content,
                  site: comment.site,
                  displayName: comment.displayName,
                  email: comment.email,
                  isPass: comment.isPass,
                ));
                if (context.mounted) showGlobalSnack( '评论已保存');
                await notifier.refresh();
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
