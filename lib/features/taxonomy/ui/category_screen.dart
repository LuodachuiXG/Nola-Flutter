import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/taxonomy.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../shell/ui/console_shell.dart';
import '../../files/data/file_api.dart';
import '../data/taxonomy_api.dart';
import '../providers/taxonomy_providers.dart';

/// 分类管理页。
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    final notifier = ref.read(categoryListProvider.notifier);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '分类',
        actions: [
          IconButton(
            tooltip: '添加分类',
            icon: const Icon(Icons.add),
            onPressed: () => showCategoryForm(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncValueWidget<List<Category>>(
        value: categories,
        error: (context, error) => ErrorPlaceholder(
          message: '$error',
          onRetry: notifier.reload,
        ),
        builder: (context, data) {
          if (data.isEmpty) {
            return const EmptyPlaceholder(
              icon: Icons.category_outlined,
              message: '还没有分类，点击右上角创建',
            );
          }
          return RefreshIndicator(
            onRefresh: notifier.reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _CategoryTile(category: data[index]),
            ),
          );
        },
      ),
    );
  }
}

/// 分类列表项。
class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: category.cover != null && category.cover!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.network(
                    category.cover!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_outlined),
              ),
        title: Text(category.displayName),
        subtitle: Text(
          '${category.slug} · ${category.postCount ?? 0} 篇文章'
          '${category.unifiedCover ? ' · 统一封面' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await showCategoryForm(context, ref, category: category);
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
      title: '删除分类',
      content: '确定删除分类「${category.displayName}」吗？',
      danger: true,
      confirmText: '删除',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(taxonomyApiProvider)
          .deleteCategories([category.categoryId]);
      await ref.read(categoryListProvider.notifier).reload();
      if (context.mounted) showGlobalSnack( '分类已删除');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}

/// 展示分类新建 / 编辑表单（供列表页与列表项共用）。
Future<void> showCategoryForm(
  BuildContext context,
  WidgetRef ref, {
  Category? category,
}) async {
  final displayNameController =
      TextEditingController(text: category?.displayName ?? '');
  final slugController = TextEditingController(text: category?.slug ?? '');
  final coverController = TextEditingController(text: category?.cover ?? '');
  var unifiedCover = category?.unifiedCover ?? false;
  var uploading = false;

  await showFormSheet(
    context,
    title: category == null ? '添加分类' : '修改分类',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: '分类名'),
            autofocus: category == null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: slugController,
            decoration: const InputDecoration(labelText: '别名（URL）'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: coverController,
                  decoration: const InputDecoration(labelText: '封面地址（可选）'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: uploading
                    ? null
                    : () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        final file = result?.files.single;
                        if (file == null || file.bytes == null) return;
                        setState(() => uploading = true);
                        try {
                          final item =
                              await ref.read(fileApiProvider).upload(
                                    fileName: file.name,
                                    fileBytes: file.bytes!,
                                  );
                          if (item != null) {
                            coverController.text = item.url;
                          } else if (context.mounted) {
                            showGlobalSnack( '封面上传失败', error: true);
                          }
                        } on ApiException catch (error) {
                          if (context.mounted) {
                            showGlobalSnack( error.message, error: true);
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => uploading = false);
                          }
                        }
                      },
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('统一封面'),
            subtitle: const Text('未单独设置封面的文章使用分类封面'),
            value: unifiedCover,
            onChanged: (value) => setState(() => unifiedCover = value),
          ),
        ],
      ),
    ),
    onSave: () async {
      final displayName = displayNameController.text.trim();
      final slug = slugController.text.trim();
      if (displayName.isEmpty || slug.isEmpty) {
        showGlobalSnack( '分类名和别名不能为空', error: true);
        return false;
      }
      final api = ref.read(taxonomyApiProvider);
      final cover = coverController.text.trim();
      try {
        if (category == null) {
          await api.addCategory(Category(
            categoryId: -1,
            displayName: displayName,
            slug: slug,
            cover: cover.isEmpty ? null : cover,
            unifiedCover: unifiedCover,
          ));
          showGlobalSnack( '分类已添加');
        } else {
          await api.updateCategory(Category(
            categoryId: category.categoryId,
            displayName: displayName,
            slug: slug,
            cover: cover.isEmpty ? null : cover,
            unifiedCover: unifiedCover,
          ));
          showGlobalSnack( '分类已保存');
        }
        await ref.read(categoryListProvider.notifier).reload();
        return true;
      } on ApiException catch (error) {
        showGlobalSnack( error.message, error: true);
        return false;
      }
    },
  );
}
