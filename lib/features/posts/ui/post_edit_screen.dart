import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/post.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/post_providers.dart';
import 'post_setting_sheet.dart';

/// 文章编辑页（全屏，不带控制台导航）。
///
/// 支持编辑正文、草稿的保存 / 加载 / 重命名 / 转正文 / 删除。
class PostEditScreen extends ConsumerWidget {
  const PostEditScreen({super.key, this.postId});

  /// 文章 ID，必须已创建文章后才能进入编辑器。
  final int? postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (postId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('文章编辑')),
        body: const ErrorPlaceholder(message: '缺少文章 ID，请先创建文章'),
      );
    }

    final editor = ref.watch(postEditorProvider(postId!));

    return PopScope(
      // 有未保存修改时拦截返回，提示确认
      canPop: !(editor.value?.dirty ?? false),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await showConfirmDialog(
          context,
          title: '放弃修改？',
          content: '当前内容尚未保存，离开后将丢失修改。',
          danger: true,
          confirmText: '离开',
        );
        if (confirmed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, ref, editor),
        body: AsyncValueWidget<EditorState>(
          value: editor,
          builder: (context, state) => _EditorBody(
            postId: postId!,
            state: state,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<EditorState> editor,
  ) {
    final state = editor.value;
    return AppBar(
      title: Text(
        state?.post.title ?? '文章编辑',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (state != null && state.dirty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                '未保存',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          ),
        IconButton(
          tooltip: '文章设置',
          icon: const Icon(Icons.settings_outlined),
          onPressed: state == null
              ? null
              : () => showPostSettingSheet(
                    context,
                    post: state.post,
                    onSaved: (_) async {
                      await ref
                          .read(postEditorProvider(state.post.postId).notifier)
                          .refreshPost();
                    },
                  ),
        ),
        IconButton(
          tooltip: '草稿管理',
          icon: const Icon(Icons.history_rounded),
          onPressed: state == null
              ? null
              : () => _showDraftSheet(context, ref, state.post.postId),
        ),
        if (state != null && state.tab == EditorTab.publish)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: state.saving
                  ? null
                  : () => _savePublish(context, ref, state.post.postId),
              icon: state.saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存正文'),
            ),
          ),
      ],
    );
  }

  Future<void> _savePublish(BuildContext context, WidgetRef ref, int postId) async {
    try {
      await ref.read(postEditorProvider(postId).notifier).savePublish();
      if (context.mounted) showGlobalSnack( '正文已保存');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 草稿管理弹层。
  void _showDraftSheet(BuildContext context, WidgetRef ref, int postId) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => _DraftSheet(postId: postId),
    );
  }
}

/// 编辑器主体。
class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({required this.postId, required this.state});

  final int postId;
  final EditorState state;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.content);
  }

  @override
  void didUpdateWidget(_EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换正文 / 草稿时同步编辑器文本
    final switchedTab = widget.state.tab != oldWidget.state.tab ||
        widget.state.draftName != oldWidget.state.draftName;
    if (switchedTab && widget.state.content != _controller.text) {
      _controller.text = widget.state.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final notifier = ref.read(postEditorProvider(widget.postId).notifier);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部状态栏：当前编辑的内容类型
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: theme.colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('正文'),
                    selected: state.tab == EditorTab.publish,
                    onSelected: state.loadingContent
                        ? null
                        : (_) => _loadPublish(notifier),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      state.tab == EditorTab.draft && state.draftName != null
                          ? '草稿：${state.draftName}'
                          : '草稿',
                    ),
                    selected: state.tab == EditorTab.draft,
                    onSelected: state.loadingContent
                        ? null
                        : (_) => _showDraftSheet(context),
                  ),
                  const Spacer(),
                  Text(
                    '${state.content.length} 字',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.loadingContent
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText: '使用 Markdown 撰写文章内容…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: notifier.updateContent,
                      ),
                    ),
            ),
          ],
        ),
        if (state.saving)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _loadPublish(PostEditorNotifier notifier) async {
    try {
      await notifier.loadPublish();
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    }
  }

  void _showDraftSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => _DraftSheet(postId: widget.postId),
    );
  }
}

/// 草稿管理弹层。
class _DraftSheet extends ConsumerWidget {
  const _DraftSheet({required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(postEditorProvider(postId));
    final notifier = ref.read(postEditorProvider(postId).notifier);
    final theme = Theme.of(context);
    final state = editor.value;

    if (state == null) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final drafts = state.contents
        .where((c) => c.status == PostContentStatus.draft)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('草稿管理', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: state.content.isEmpty
                        ? null
                        : () => _saveAsDraft(context, notifier),
                    icon: const Icon(Icons.save_as_outlined, size: 18),
                    label: const Text('存为草稿'),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            if (drafts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无草稿',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final draft in drafts)
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(draft.draftName ?? ''),
                        subtitle: Text(
                          '修改于 ${formatDateTime(draft.lastModifyTime)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleDraftAction(
                            context,
                            ref,
                            notifier,
                            draft,
                            value,
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'load',
                              child: Text('加载到编辑器'),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('重命名'),
                            ),
                            const PopupMenuItem(
                              value: 'publish',
                              child: Text('转为正文'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                        onTap: () => _handleDraftAction(
                          context,
                          ref,
                          notifier,
                          draft,
                          'load',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 将编辑器当前内容存为草稿。
  Future<void> _saveAsDraft(
    BuildContext context,
    PostEditorNotifier notifier,
  ) async {
    final controller = await _promptTextInput(
      context,
      title: '草稿名称',
      hint: '输入草稿名称',
    );
    if (controller == null || controller.isEmpty) return;
    try {
      await notifier.saveDraft(controller);
      if (context.mounted) {
        showGlobalSnack( '已保存草稿');
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  Future<void> _handleDraftAction(
    BuildContext context,
    WidgetRef ref,
    PostEditorNotifier notifier,
    PostContentMeta draft,
    String action,
  ) async {
    final draftName = draft.draftName ?? '';
    try {
      switch (action) {
        case 'load':
          await notifier.loadDraft(draftName);
          if (context.mounted) Navigator.of(context).pop();
        case 'rename':
          final newName = await _promptTextInput(
            context,
            title: '重命名草稿',
            hint: '新的草稿名称',
            initialText: draftName,
          );
          if (newName == null || newName.isEmpty) return;
          await notifier.renameDraft(oldName: draftName, newName: newName);
          if (context.mounted) showGlobalSnack( '已重命名');
        case 'publish':
          final confirmed = await _promptDraft2Content(context);
          if (confirmed == null) return;
          await notifier.publishDraft(
            draftName: draftName,
            deleteContent: confirmed.deleteContent,
            contentName: confirmed.contentName,
          );
          if (context.mounted) {
            showGlobalSnack( '已转换为正文');
            Navigator.of(context).pop();
          }
        case 'delete':
          final confirmed = await showConfirmDialog(
            context,
            title: '删除草稿',
            content: '确定删除草稿「$draftName」吗？',
            danger: true,
            confirmText: '删除',
          );
          if (!confirmed) return;
          await notifier.deleteDraft(draftName);
          if (context.mounted) showGlobalSnack( '草稿已删除');
      }
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 通用文本输入弹窗。
  Future<String?> _promptTextInput(
    BuildContext context, {
    required String title,
    required String hint,
    String? initialText,
  }) {
    final controller = TextEditingController(text: initialText ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 草稿转正文选项弹窗。
  Future<_Draft2ContentOptions?> _promptDraft2Content(
    BuildContext context,
  ) async {
    var deleteContent = false;
    final contentNameController = TextEditingController();
    final result = await showDialog<_Draft2ContentOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('转为正文'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('删除原正文'),
                subtitle: const Text('不删除时，原正文将转存为草稿'),
                value: deleteContent,
                onChanged: (value) =>
                    setState(() => deleteContent = value ?? false),
              ),
              if (!deleteContent)
                TextField(
                  controller: contentNameController,
                  decoration: const InputDecoration(
                    labelText: '原正文转存的草稿名（可选）',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _Draft2ContentOptions(
                  deleteContent: deleteContent,
                  contentName: contentNameController.text.trim().isEmpty
                      ? null
                      : contentNameController.text.trim(),
                ),
              ),
              child: const Text('转换'),
            ),
          ],
        ),
      ),
    );
    return result;
  }
}

/// 草稿转正文选项。
class _Draft2ContentOptions {
  const _Draft2ContentOptions({
    required this.deleteContent,
    this.contentName,
  });

  final bool deleteContent;
  final String? contentName;
}
