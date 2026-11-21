import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/file_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/file_api.dart';
import '../providers/file_providers.dart';

/// 附件管理页。
class FileScreen extends ConsumerWidget {
  const FileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(fileListProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final groups = ref.watch(fileGroupsProvider);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '附件',
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              switch (value) {
                case 'groups':
                  _showGroupManager(context, ref);
                case 'storage':
                  _showStorageConfig(context, ref);
                case 'record':
                  _showAddRecord(context, ref);
                case 'search':
                  _showSearchDialog(context, ref, notifier);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'groups',
                child: ListTile(
                  leading: Icon(Icons.folder_copy_outlined),
                  title: Text('分组管理'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'storage',
                child: ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('存储设置'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'record',
                child: ListTile(
                  leading: Icon(Icons.link_rounded),
                  title: Text('添加文件记录'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'search',
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('搜索文件'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: '上传文件',
            icon: const Icon(Icons.upload_rounded),
            onPressed: () => _uploadFiles(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 筛选条：分组
          SizedBox(
            height: 52,
            child: groups.when(
              data: (data) => ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _FilterChip(
                    label: '全部分组',
                    selected: notifier.filter.groupId == null,
                    onTap: () => _applyGroupId(ref, context, null),
                  ),
                  for (final group in data)
                    _FilterChip(
                      label: group.displayName,
                      selected: notifier.filter.groupId == group.fileGroupId,
                      onTap: () => _applyGroupId(ref, context, group.fileGroupId),
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PagedListView<FileItem>(
              value: listState,
              emptyIcon: Icons.folder_open_outlined,
              noItemsMessage: '暂无文件',
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
              itemBuilder: (context, file) => _FileTile(file: file),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyGroupId(WidgetRef ref, BuildContext context, int? groupId) async {
    try {
      await ref
          .read(fileListProvider.notifier)
          .applyFilter(groupId: groupId);
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 上传文件。
  Future<void> _uploadFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    final files = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (files.isEmpty) return;
    if (!context.mounted) return;

    // 选择分组与存储方式
    final target = await _promptUploadTarget(context, ref);
    if (target == null) return;

    final api = ref.read(fileApiProvider);
    var success = 0;
    for (final file in files) {
      try {
        final item = await api.upload(
          fileName: file.name,
          fileBytes: file.bytes!,
          fileGroupId: target.groupId,
          storageMode: target.mode,
        );
        if (item != null) success++;
      } on ApiException catch (error) {
        if (context.mounted) {
          showGlobalSnack( '上传 ${file.name} 失败：${error.message}',
              error: true);
        }
      }
    }
    if (success > 0) {
      if (context.mounted) showGlobalSnack( '成功上传 $success 个文件');
      await ref.read(fileListProvider.notifier).refresh();
      ref.invalidate(fileGroupsProvider);
    }
  }

  /// 上传目标选择（分组 + 存储方式）。
  Future<_UploadTarget?> _promptUploadTarget(
    BuildContext context,
    WidgetRef ref,
  ) async {
    int? groupId;
    FileStorageMode? mode;
    final groups = await ref.read(fileGroupsProvider.future);
    if (!context.mounted) return null;

    final result = await showDialog<_UploadTarget>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('上传选项'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                initialValue: groupId,
                decoration: const InputDecoration(labelText: '文件分组'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('默认分组')),
                  for (final group in groups)
                    DropdownMenuItem(
                      value: group.fileGroupId,
                      child: Text('${group.displayName}（${group.storageMode.label}）'),
                    ),
                ],
                onChanged: (value) => setState(() => groupId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FileStorageMode?>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: '存储方式'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('默认（本地）')),
                  for (final value in FileStorageMode.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => setState(() => mode = value),
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
                _UploadTarget(groupId: groupId, mode: mode),
              ),
              child: const Text('开始上传'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  /// 分组管理弹层。
  void _showGroupManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => _GroupManagerSheet(ref: ref),
    );
  }

  /// 存储设置弹层。
  void _showStorageConfig(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => const _StorageConfigSheet(),
    );
  }

  /// 添加文件记录（登记外部文件）。
  void _showAddRecord(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();

    showFormDialog(
      context,
      title: '添加文件记录',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '文件名（含后缀）'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: sizeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '文件大小（字节）'),
          ),
        ],
      ),
      onSave: () async {
        final name = nameController.text.trim();
        final size = int.tryParse(sizeController.text.trim()) ?? 0;
        if (name.isEmpty) {
          showGlobalSnack( '文件名不能为空', error: true);
          return false;
        }
        try {
          await ref.read(fileApiProvider).addRecord(
                FileRecordRequest(name: name, size: size),
              );
          if (context.mounted) showGlobalSnack( '文件记录已添加');
          await ref.read(fileListProvider.notifier).refresh();
          return true;
        } on ApiException catch (error) {
          if (context.mounted) {
            showGlobalSnack( error.message, error: true);
          }
          return false;
        }
      },
    );
  }

  void _showSearchDialog(
    BuildContext context,
    WidgetRef ref,
    FileListNotifier notifier,
  ) {
    final controller = TextEditingController(text: notifier.filter.key ?? '');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件名关键字'),
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
                  mode: notifier.filter.mode,
                  groupId: notifier.filter.groupId,
                  sort: notifier.filter.sort,
                  key: key,
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

/// 上传目标。
class _UploadTarget {
  const _UploadTarget({this.groupId, this.mode});

  final int? groupId;
  final FileStorageMode? mode;
}

/// 分组筛选 Chip。
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// 文件列表项。
class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});

  final FileItem file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serverUrl = ref.watch(localStorageProvider).serverUrl;
    final url = resolveFileUrl(file.url, serverUrl);
    final isImage = _isImage(file.displayName);
    final notifier = ref.read(fileListProvider.notifier);

    Future<void> delete() async {
      final confirmed = await showConfirmDialog(
        context,
        title: '删除文件',
        content: '确定删除文件「${file.displayName}」吗？',
        danger: true,
        confirmText: '删除',
      );
      if (!confirmed) return;
      try {
        await ref.read(fileApiProvider).deleteFiles([file.fileId]);
        if (context.mounted) showGlobalSnack( '文件已删除');
        await notifier.refresh();
      } on ApiException catch (error) {
        if (context.mounted) showGlobalSnack( error.message, error: true);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: theme.colorScheme.surfaceContainerHighest,
            child: isImage && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.insert_drive_file_outlined),
                  )
                : const Icon(Icons.insert_drive_file_outlined),
          ),
        ),
        title: Text(
          file.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatFileSize(file.size)} · ${file.fileGroupName ?? '默认分组'} · ${file.storageMode.label}',
        ),
        onTap: isImage && url.isNotEmpty
            ? () => _preview(context, url)
            : () => _copyUrl(context, url),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'copy':
                await _copyUrl(context, url);
              case 'move':
                await _move(context, ref);
              case 'delete':
                await delete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: Icon(Icons.copy_rounded),
                title: Text('复制链接'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.drive_file_move_outlined),
                title: Text('移动到分组'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('删除'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImage(String name) {
    const exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    final lower = name.toLowerCase();
    return exts.any(lower.endsWith);
  }

  void _preview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) showGlobalSnack( '链接已复制');
  }

  /// 移动文件到其他分组。
  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final groups = await ref.read(fileGroupsProvider.future);
    if (!context.mounted) return;
    int? newGroupId = file.fileGroupId;
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('移动文件'),
          content: DropdownButtonFormField<int?>(
            initialValue: newGroupId,
            decoration: const InputDecoration(labelText: '目标分组'),
            items: [
              const DropdownMenuItem(value: null, child: Text('默认分组')),
              for (final group in groups)
                DropdownMenuItem(
                  value: group.fileGroupId,
                  child:
                      Text('${group.displayName}（${group.storageMode.label}）'),
                ),
            ],
            onChanged: (value) => setState(() => newGroupId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(newGroupId),
              child: const Text('移动'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(fileApiProvider)
          .moveFiles([file.fileId], result);
      if (context.mounted) showGlobalSnack( '文件已移动');
      await ref.read(fileListProvider.notifier).refresh();
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}

/// 分组管理弹层（使用列表页传入的 ref 操作数据）。
class _GroupManagerSheet extends StatelessWidget {
  const _GroupManagerSheet({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(fileGroupsProvider);

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
                  Text('分组管理', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _addGroup(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建分组'),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Flexible(
              child: groups.when(
                data: (data) => data.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('暂无分组')),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final group in data)
                            ListTile(
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(group.displayName),
                              subtitle: Text(
                                '${group.path} · ${group.storageMode.label}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '重命名',
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    onPressed: () => _renameGroup(context, group),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    onPressed: () =>
                                        _deleteGroup(context, group),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('$error')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGroup(BuildContext context) async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    var mode = FileStorageMode.local;

    await showFormDialog(
      context,
      title: '新建分组',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '分组名称'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pathController,
              decoration: const InputDecoration(labelText: '分组路径（如 img）'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FileStorageMode>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: '存储方式'),
              items: [
                for (final value in FileStorageMode.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) => setState(() => mode = value ?? mode),
            ),
          ],
        ),
      ),
      onSave: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          showGlobalSnack( '分组名称不能为空', error: true);
          return false;
        }
        try {
          await ref.read(fileApiProvider).addGroup(
                displayName: name,
                path: pathController.text.trim(),
                storageMode: mode,
              );
          ref.invalidate(fileGroupsProvider);
          if (context.mounted) showGlobalSnack( '分组已创建');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  Future<void> _renameGroup(BuildContext context, FileGroup group) async {
    final controller = TextEditingController(text: group.displayName);
    await showFormDialog(
      context,
      title: '重命名分组',
      builder: (context) => TextFormField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '分组名称'),
      ),
      onSave: () async {
        final name = controller.text.trim();
        if (name.isEmpty) return false;
        try {
          await ref
              .read(fileApiProvider)
              .updateGroup(fileGroupId: group.fileGroupId, displayName: name);
          ref.invalidate(fileGroupsProvider);
          if (context.mounted) showGlobalSnack( '分组已重命名');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  Future<void> _deleteGroup(BuildContext context, FileGroup group) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除分组',
      content: '确定删除分组「${group.displayName}」吗？组内文件将移动到默认分组。',
      danger: true,
      confirmText: '删除',
    );
    if (!confirmed) return;
    try {
      await ref.read(fileApiProvider).deleteGroup(group.fileGroupId);
      ref.invalidate(fileGroupsProvider);
      ref.read(fileListProvider.notifier).refresh();
      if (context.mounted) showGlobalSnack( '分组已删除');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}

/// 存储设置弹层（腾讯云 COS 配置）。
class _StorageConfigSheet extends ConsumerWidget {
  const _StorageConfigSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tencentCOSProvider);
    final modes = ref.watch(storageModesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('存储设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            modes.when(
              data: (data) => Wrap(
                spacing: 8,
                children: [
                  for (final mode in data)
                    Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(mode.label),
                    ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
            ),
            const SizedBox(height: 16),
            config.when(
              data: (data) => ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('腾讯云对象存储'),
                subtitle: Text(data == null
                    ? '未配置'
                    : '${data.bucket} · ${data.region}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: data == null
                          ? null
                          : () => _editConfig(context, ref, data),
                      child: const Text('编辑'),
                    ),
                    TextButton(
                      onPressed: data == null
                          ? null
                          : () => _deleteConfig(context, ref),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editConfig(context, ref, null),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('配置腾讯云对象存储'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editConfig(
    BuildContext context,
    WidgetRef ref,
    TencentCOSConfig? config,
  ) async {
    final secretIdController =
        TextEditingController(text: config?.secretId ?? '');
    final secretKeyController =
        TextEditingController(text: config?.secretKey ?? '');
    final regionController = TextEditingController(text: config?.region ?? '');
    final bucketController = TextEditingController(text: config?.bucket ?? '');
    final pathController = TextEditingController(text: config?.path ?? '');
    var https = config?.https ?? true;

    await showFormDialog(
      context,
      title: '腾讯云 COS 配置',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: secretIdController,
              decoration: const InputDecoration(labelText: 'SecretId'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: secretKeyController,
              decoration: const InputDecoration(labelText: 'SecretKey'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: regionController,
              decoration: const InputDecoration(labelText: '地域（如 ap-guangzhou）'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bucketController,
              decoration: const InputDecoration(labelText: '存储桶'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pathController,
              decoration: const InputDecoration(labelText: '存储路径（可选）'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用 HTTPS'),
              value: https,
              onChanged: (value) => setState(() => https = value),
            ),
          ],
        ),
      ),
      onSave: () async {
        if (secretIdController.text.isEmpty ||
            secretKeyController.text.isEmpty ||
            regionController.text.isEmpty ||
            bucketController.text.isEmpty) {
          showGlobalSnack( '请填写完整的配置信息', error: true);
          return false;
        }
        try {
          await ref.read(fileApiProvider).setTencentCOS(TencentCOSConfig(
                secretId: secretIdController.text.trim(),
                secretKey: secretKeyController.text.trim(),
                region: regionController.text.trim(),
                bucket: bucketController.text.trim(),
                path: pathController.text.trim().isEmpty
                    ? null
                    : pathController.text.trim(),
                https: https,
              ));
          ref.invalidate(tencentCOSProvider);
          ref.invalidate(storageModesProvider);
          if (context.mounted) showGlobalSnack( '配置已保存');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  Future<void> _deleteConfig(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除配置',
      content: '确定删除腾讯云 COS 配置吗？',
      danger: true,
      confirmText: '删除',
    );
    if (!confirmed) return;
    try {
      await ref.read(fileApiProvider).deleteTencentCOS();
      ref.invalidate(tencentCOSProvider);
      ref.invalidate(storageModesProvider);
      if (context.mounted) showGlobalSnack( '配置已删除');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}
