import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/system_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/system_temp.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../shell/ui/console_shell.dart';
import '../data/backup_api.dart';

/// 备份页：文章导入、导出与备份恢复。
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const ConsoleAppBar(title: '备份'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BackupCard(
            icon: Icons.download_rounded,
            title: '导出文章',
            description: '将全部文章导出为 Markdown 文件压缩包并分享保存',
            actionLabel: '导出',
            onAction: () => _exportPosts(context, ref),
          ),
          const SizedBox(height: 12),
          _BackupCard(
            icon: Icons.upload_file_rounded,
            title: '导入文章',
            description: '选择 Markdown 或 Txt 文件批量创建文章',
            actionLabel: '导入',
            onAction: () => _importPosts(context, ref),
          ),
          const SizedBox(height: 12),
          _BackupCard(
            icon: Icons.restore_rounded,
            title: '恢复备份',
            description: '上传导出的 zip 备份，先预览预计操作，确认后执行恢复',
            actionLabel: '恢复',
            onAction: () => _restoreBackup(context, ref),
            danger: true,
          ),
        ],
      ),
    );
  }

  /// 导出文章并分享压缩包。
  Future<void> _exportPosts(BuildContext context, WidgetRef ref) async {
    final api = ref.read(backupApiProvider);
    try {
      showGlobalSnack( '正在导出文章…');
      final result = await api.exportPosts();
      if (!context.mounted) return;
      showSnack(
        context,
        '导出完成：成功 ${result.successCount}/${result.count} 篇'
        '${result.failCount > 0 ? '，失败 ${result.failCount} 篇' : ''}',
        error: result.failCount > 0,
      );

      // 下载到临时目录后分享
      final fileName = result.path.split('/').last;
      final savePath = '${systemTempPath()}/$fileName';
      await api.downloadExport(fileName, savePath);
      // Web 端 dio.download 已触发浏览器直接下载 zip，
      // 本地路径分享不可用，跳过
      if (kIsWeb) return;
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(savePath)], text: 'Nola 文章备份'),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 导入 Markdown / Txt 文章。
  Future<void> _importPosts(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['md', 'txt'],
      withData: true,
    );
    final files = result?.files.where((f) => f.bytes != null).toList() ?? [];
    if (files.isEmpty) return;
    if (!context.mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '导入文章',
      content: '将导入 ${files.length} 个文件为新文章，确认继续吗？',
    );
    if (!confirmed) return;

    try {
      showGlobalSnack( '正在导入…');
      final importResult = await ref.read(backupApiProvider).importPosts({
        for (final file in files) file.name: file.bytes!,
      });
      if (!context.mounted) return;
      final errorText = importResult.failResult.isEmpty
          ? ''
          : '\n失败：${importResult.failResult.take(3).join('；')}';
      showSnack(
        context,
        '导入完成：成功 ${importResult.successCount}/${importResult.fileCount}$errorText',
        error: importResult.failCount > 0,
      );
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 恢复备份（预览 → 确认 → 执行）。
  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    // 空列表时 files.single 会抛 StateError，安全取第一个
    final file = (result == null || result.files.isEmpty)
        ? null
        : result.files.first;
    if (file == null || file.bytes == null) return;

    try {
      showGlobalSnack( '正在解析备份文件…');
      final preview = await ref.read(backupApiProvider).previewRestore(
            fileName: file.name,
            fileBytes: file.bytes!,
          );
      if (!context.mounted) return;
      await _showRestorePreview(context, ref, preview);
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }

  /// 展示恢复预览并确认执行。
  Future<void> _showRestorePreview(
    BuildContext context,
    WidgetRef ref,
    RestorePreview preview,
  ) async {
    var strategy = 'SKIP';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('恢复预览', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  '共 ${preview.totalFiles} 个文件（正文 ${preview.publishedFiles}，'
                  '草稿 ${preview.draftFiles}）\n'
                  '新建文章 ${preview.createPostCount} 篇 · 更新正文 ${preview.updatePostCount} 篇 · '
                  '新增草稿 ${preview.addDraftCount} 个',
                ),
                if (preview.conflictCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '存在 ${preview.conflictCount} 个冲突文件（跳过 ${preview.skipCount}，无法识别 ${preview.invalidCount}）',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (preview.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final warning in preview.warnings)
                    Text(
                      '· $warning',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: strategy,
                  decoration: const InputDecoration(labelText: '冲突处理策略'),
                  items: const [
                    DropdownMenuItem(value: 'SKIP', child: Text('跳过冲突文件')),
                    DropdownMenuItem(value: 'RENAME', child: Text('重命名后恢复')),
                  ],
                  onChanged: (value) =>
                      setState(() => strategy = value ?? 'SKIP'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('执行恢复'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await ref.read(backupApiProvider).applyRestore(
            token: preview.token,
            conflictStrategy: strategy,
          );
      if (!context.mounted) return;
      showSnack(
        context,
        '恢复完成：新建 ${result.createdPosts} 篇，更新 ${result.updatedPosts} 篇，'
        '新增草稿 ${result.addedDrafts} 个'
        '${result.failedFiles > 0 ? '，失败 ${result.failedFiles} 个' : ''}',
        error: result.failedFiles > 0,
      );
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}

/// 备份操作卡片。
class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: danger ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: danger
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
