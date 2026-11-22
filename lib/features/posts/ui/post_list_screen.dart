import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/post.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/post_api.dart';
import '../providers/post_providers.dart';
import 'post_setting_sheet.dart';

/// 文章状态标签页定义。
class _StatusTab {
  const _StatusTab(this.label, this.status);

  final String label;
  final PostStatus? status;
}

const List<_StatusTab> _statusTabs = [
  _StatusTab('全部', null),
  _StatusTab('已发布', PostStatus.published),
  _StatusTab('草稿', PostStatus.draft),
  _StatusTab('回收站', PostStatus.deleted),
];

/// 文章列表页。
class PostListScreen extends ConsumerStatefulWidget {
  const PostListScreen({super.key});

  @override
  ConsumerState<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends ConsumerState<PostListScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 切换状态标签。
  Future<void> _onTabChanged(int index) async {
    try {
      await ref
          .read(postListProvider.notifier)
          .setStatus(_statusTabs[index].status);
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 提交搜索关键字。
  Future<void> _submitSearch(String key) async {
    try {
      await ref.read(postListProvider.notifier).applyFilter(key: key.trim());
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 打开高级筛选。
  Future<void> _openFilterSheet() async {
    final notifier = ref.read(postListProvider.notifier);
    final current = notifier.filter;
    final result = await showPostFilterSheet(context, current);
    if (result == null) return;
    try {
      await notifier.applyFilter(
        visible: result.visible,
        sort: result.sort,
        categoryId: result.categoryId,
        tagId: result.tagId,
        key: result.key,
      );
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 新建文章。
  void _createPost() {
    showPostSettingSheet(
      context,
      onSaved: (post) {
        if (!mounted) return;
        // 创建成功后直接进入编辑器
        context.push('/post-editor?postId=${post.postId}');
        ref.read(postListProvider.notifier).refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(postListProvider);
    final notifier = ref.read(postListProvider.notifier);
    final activeIndex = _statusTabs
        .indexWhere((tab) => tab.status == notifier.filter.status);

    return DefaultTabController(
      length: _statusTabs.length,
      initialIndex: activeIndex < 0 ? 0 : activeIndex,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return Scaffold(
            appBar: ConsoleAppBar(
              title: '文章',
              actions: [
                IconButton(
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  tooltip: '搜索',
                  onPressed: () {
                    setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _searchController.clear();
                        _submitSearch('');
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: '筛选',
                  onPressed: _openFilterSheet,
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                // 搜索框展开时需追加其高度，否则 AppBar bottom 内容溢出
                preferredSize: Size.fromHeight(
                  kToolbarHeight * 0.85 + (_searching ? 56 : 0),
                ),
                child: Column(
                  children: [
                    if (_searching)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: '搜索文章标题或内容',
                            prefixIcon: Icon(Icons.search),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: _submitSearch,
                        ),
                      ),
                    TabBar(
                      controller: tabController,
                      isScrollable: true,
                      dividerHeight: 0,
                      onTap: _onTabChanged,
                      tabs: [
                        for (final tab in _statusTabs) Tab(text: tab.label),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: const Text('新建文章'),
            ),
            body: PagedListView<Post>(
              value: listState,
              onRefresh: () async {
                try {
                  await notifier.refresh();
                } on ApiException catch (error) {
                  if (mounted) showGlobalSnack( error.message, error: true);
                }
              },
              onLoadMore: () async {
                await notifier.loadMore();
                final error = ref.read(postListProvider).value?.loadMoreError;
                if (error != null && mounted) {
                  showGlobalSnack( error, error: true);
                }
              },
              noItemsMessage: notifier.filter.status == PostStatus.deleted
                  ? '回收站没有文章'
                  : '还没有文章，点击右下角创建',
              itemBuilder: (context, post) =>
                  _PostListItem(post: post, onChanged: () => notifier.refresh()),
            ),
          );
        },
      ),
    );
  }
}

/// 文章列表项。
class _PostListItem extends ConsumerWidget {
  const _PostListItem({required this.post, required this.onChanged});

  final Post post;
  final VoidCallback onChanged;

  Future<void> _handleAction(BuildContext context, WidgetRef ref,
      Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (context.mounted) showGlobalSnack( successMessage);
      onChanged();
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(postApiProvider);
    final isDeleted = post.status == PostStatus.deleted;

    // 封面地址：文章自己的封面优先，其次使用分类的统一封面。
    final cover = post.cover?.isNotEmpty == true
        ? post.cover
        : (post.category?.unifiedCover == true ? post.category?.cover : null);
    final serverUrl = ref.read(localStorageProvider).serverUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDeleted
            ? null
            : () => context.push('/post-editor?postId=${post.postId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null && cover.isNotEmpty) ...[
                _CoverThumb(url: resolveFileUrl(cover, serverUrl)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (post.pinned == true) ...[
                          Icon(Icons.push_pin_rounded,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                        ],
                        if (post.encrypted) ...[
                          Icon(Icons.lock_outline,
                              size: 16, color: theme.colorScheme.tertiary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MetaChip(label: post.status.label),
                        if (post.visible == PostVisible.hidden)
                          _MetaChip(
                            label: post.visible.label,
                            color: theme.colorScheme.error,
                          ),
                        if (post.category != null)
                          _MetaChip(label: post.category!.displayName),
                        for (final tag in post.tags)
                          _MetaChip(
                            label: tag.displayName,
                            color: parseHexColor(tag.color) == null
                                ? null
                                : Color(parseHexColor(tag.color)!),
                          ),
                        _MetaChip(label: '浏览 ${post.visit}'),
                        _MetaChip(label: formatDateTime(post.createTime)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      context.push('/post-editor?postId=${post.postId}');
                    case 'settings':
                      showPostSettingSheet(
                        context,
                        post: post,
                        onSaved: (_) => onChanged(),
                      );
                    case 'pin':
                      await _handleAction(
                        context,
                        ref,
                        () => api.updatePostStatus(
                          postId: post.postId,
                          pinned: !(post.pinned ?? false),
                        ),
                        (post.pinned ?? false) ? '已取消置顶' : '已置顶',
                      );
                    case 'hide':
                      final newVisible = post.visible == PostVisible.visible
                          ? PostVisible.hidden
                          : PostVisible.visible;
                      await _handleAction(
                        context,
                        ref,
                        () => api.updatePostStatus(
                          postId: post.postId,
                          visible: newVisible,
                        ),
                        newVisible == PostVisible.hidden ? '已隐藏' : '已设为可见',
                      );
                    case 'recycle':
                      final confirmed = await showConfirmDialog(
                        context,
                        title: '移入回收站',
                        content: '确定将文章「${post.title}」移入回收站吗？',
                        danger: true,
                      );
                      if (!confirmed || !context.mounted) return;
                      await _handleAction(
                        context,
                        ref,
                        () => api.recyclePosts([post.postId]),
                        '已移入回收站',
                      );
                    case 'restore_published':
                      await _handleAction(
                        context,
                        ref,
                        () => api.restorePosts(
                          [post.postId],
                          PostStatus.published,
                        ),
                        '已恢复为已发布',
                      );
                    case 'restore_draft':
                      await _handleAction(
                        context,
                        ref,
                        () => api.restorePosts([post.postId], PostStatus.draft),
                        '已恢复为草稿',
                      );
                    case 'delete':
                      final confirmed = await showConfirmDialog(
                        context,
                        title: '彻底删除',
                        content: '删除后文章「${post.title}」将无法恢复，确定继续吗？',
                        danger: true,
                        confirmText: '删除',
                      );
                      if (!confirmed || !context.mounted) return;
                      await _handleAction(
                        context,
                        ref,
                        () => api.deletePosts([post.postId]),
                        '已删除',
                      );
                  }
                },
                itemBuilder: (context) => [
                  if (!isDeleted) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑内容'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('文章设置'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: ListTile(
                        leading: Icon(
                          post.pinned == true
                              ? Icons.push_pin_outlined
                              : Icons.push_pin_rounded,
                        ),
                        title: Text(post.pinned == true ? '取消置顶' : '置顶'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'hide',
                      child: ListTile(
                        leading: Icon(
                          post.visible == PostVisible.visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        title: Text(
                          post.visible == PostVisible.visible ? '隐藏' : '设为可见',
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'recycle',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('移入回收站'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ] else ...[
                    const PopupMenuItem(
                      value: 'restore_published',
                      child: ListTile(
                        leading: Icon(Icons.publish_rounded),
                        title: Text('恢复为已发布'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'restore_draft',
                      child: ListTile(
                        leading: Icon(Icons.notes_rounded),
                        title: Text('恢复为草稿'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_forever_outlined),
                        title: Text('彻底删除'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文章元信息小标签。
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.12) ??
            theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 文章高级筛选结果。
class PostFilterResult {
  const PostFilterResult({
    this.visible,
    this.sort,
    this.categoryId,
    this.tagId,
    this.key,
  });

  final PostVisible? visible;
  final PostSort? sort;
  final int? categoryId;
  final int? tagId;
  final String? key;
}

/// 展示文章高级筛选弹层，返回筛选结果（null 表示取消）。
Future<PostFilterResult?> showPostFilterSheet(
  BuildContext context,
  PostFilter current,
) {
  PostVisible? visible = current.visible;
  PostSort? sort = current.sort;
  int? categoryId = current.categoryId;
  int? tagId = current.tagId;
  final keyController = TextEditingController(text: current.key ?? '');

  return showModalBottomSheet<PostFilterResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '高级筛选',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PostVisible>(
                initialValue: visible,
                decoration: const InputDecoration(labelText: '可见性'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final value in PostVisible.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => setState(() => visible = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PostSort>(
                initialValue: sort,
                decoration: const InputDecoration(labelText: '排序'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('默认')),
                  for (final value in PostSort.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => setState(() => sort = value),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, sheetRef, _) =>
                    sheetRef.watch(allCategoriesProvider).when(
                  data: (data) => DropdownButtonFormField<int?>(
                    // 筛选引用的分类可能已被删除，失效时回退为「全部」，
                    // 避免下拉框 value 不在 items 中触发断言
                    initialValue:
                        data.any((c) => c.categoryId == categoryId)
                            ? categoryId
                            : null,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部')),
                      for (final category in data)
                        DropdownMenuItem(
                          value: category.categoryId,
                          child: Text(category.displayName),
                        ),
                    ],
                    onChanged: (value) => setState(() => categoryId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('分类加载失败：$error'),
                ),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, sheetRef, _) =>
                    sheetRef.watch(allTagsProvider).when(
                  data: (data) => DropdownButtonFormField<int?>(
                    // 筛选引用的标签可能已被删除，失效时回退为「全部」
                    initialValue: data.any((t) => t.tagId == tagId)
                        ? tagId
                        : null,
                    decoration: const InputDecoration(labelText: '标签'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部')),
                      for (final tag in data)
                        DropdownMenuItem(
                          value: tag.tagId,
                          child: Text(tag.displayName),
                        ),
                    ],
                    onChanged: (value) => setState(() => tagId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('标签加载失败：$error'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '关键字'),
                controller: keyController,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(
                        const PostFilterResult(),
                      ),
                      child: const Text('清除筛选'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        PostFilterResult(
                          visible: visible,
                          sort: sort,
                          categoryId: categoryId,
                          tagId: tagId,
                          key: keyController.text.trim(),
                        ),
                      ),
                      child: const Text('应用'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 文章列表封面缩略图（56×56，圆角，加载失败显示占位图标）。
class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.broken_image_outlined,
            size: 24,
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
