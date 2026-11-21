import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/taxonomy.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../shell/ui/console_shell.dart';
import '../data/taxonomy_api.dart';
import '../providers/taxonomy_providers.dart';

/// 标签可选颜色（Nola 常用色板）。
const List<String> kTagColors = [
  '#3FB27F',
  '#4C8BF5',
  '#F59E0B',
  '#EF4444',
  '#8B5CF6',
  '#EC4899',
  '#06B6D4',
  '#84CC16',
  '#F97316',
  '#64748B',
];

/// 标签管理页。
class TagScreen extends ConsumerWidget {
  const TagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagListProvider);
    final notifier = ref.read(tagListProvider.notifier);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '标签',
        actions: [
          IconButton(
            tooltip: '添加标签',
            icon: const Icon(Icons.add),
            onPressed: () => showTagForm(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncValueWidget<List<Tag>>(
        value: tags,
        error: (context, error) => ErrorPlaceholder(
          message: '$error',
          onRetry: notifier.reload,
        ),
        builder: (context, data) {
          if (data.isEmpty) {
            return const EmptyPlaceholder(
              icon: Icons.sell_outlined,
              message: '还没有标签，点击右上角创建',
            );
          }
          return RefreshIndicator(
            onRefresh: notifier.reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _TagTile(tag: data[index]),
            ),
          );
        },
      ),
    );
  }
}

/// 展示标签新建 / 编辑表单。
Future<void> showTagForm(
  BuildContext context,
  WidgetRef ref, {
  Tag? tag,
}) async {
  final displayNameController =
      TextEditingController(text: tag?.displayName ?? '');
  final slugController = TextEditingController(text: tag?.slug ?? '');
  var color = tag?.color ?? kTagColors.first;

  await showFormSheet(
    context,
    title: tag == null ? '添加标签' : '修改标签',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: '标签名'),
            autofocus: tag == null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: slugController,
            decoration: const InputDecoration(labelText: '别名（URL）'),
          ),
          const SizedBox(height: 16),
          Text('颜色', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in kTagColors)
                InkWell(
                  onTap: () => setState(() => color = preset),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(parseHexColor(preset) ?? 0xFF3FB27F),
                      shape: BoxShape.circle,
                      border: color == preset
                          ? Border.all(
                              width: 3,
                              color: Theme.of(context).colorScheme.outline,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: color,
            decoration: const InputDecoration(labelText: '自定义颜色（#RRGGBB）'),
            onChanged: (value) => color = value.trim(),
          ),
        ],
      ),
    ),
    onSave: () async {
      final displayName = displayNameController.text.trim();
      final slug = slugController.text.trim();
      if (displayName.isEmpty || slug.isEmpty) {
        showGlobalSnack( '标签名和别名不能为空', error: true);
        return false;
      }
      final api = ref.read(taxonomyApiProvider);
      try {
        if (tag == null) {
          await api.addTag(Tag(
            tagId: -1,
            displayName: displayName,
            slug: slug,
            color: color,
          ));
          showGlobalSnack( '标签已添加');
        } else {
          await api.updateTag(Tag(
            tagId: tag.tagId,
            displayName: displayName,
            slug: slug,
            color: color,
          ));
          showGlobalSnack( '标签已保存');
        }
        await ref.read(tagListProvider.notifier).reload();
        return true;
      } on ApiException catch (error) {
        showGlobalSnack( error.message, error: true);
        return false;
      }
    },
  );
}

/// 标签列表项。
class _TagTile extends ConsumerWidget {
  const _TagTile({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = parseHexColor(tag.color);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color == null
                ? theme.colorScheme.primaryContainer
                : Color(color).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sell_outlined,
            color: color == null
                ? theme.colorScheme.onPrimaryContainer
                : Color(color),
          ),
        ),
        title: Text(tag.displayName),
        subtitle: Text('${tag.slug} · ${tag.postCount ?? 0} 篇文章'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await showTagForm(context, ref, tag: tag);
            } else if (value == 'delete') {
              await _delete(context, ref);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('编辑'),
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除标签',
      content: '确定删除标签「${tag.displayName}」吗？',
      danger: true,
      confirmText: '删除',
    );
    if (!confirmed) return;
    try {
      await ref.read(taxonomyApiProvider).deleteTags([tag.tagId]);
      await ref.read(tagListProvider.notifier).reload();
      if (context.mounted) showGlobalSnack( '标签已删除');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}
