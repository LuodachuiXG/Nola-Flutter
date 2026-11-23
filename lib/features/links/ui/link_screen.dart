import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/utils/external_link.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/link_api.dart';
import '../providers/link_providers.dart';

/// 友情链接管理页。
class LinkScreen extends ConsumerWidget {
  const LinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(linkListProvider);
    final notifier = ref.read(linkListProvider.notifier);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '友链',
        actions: [
          PopupMenuButton<LinkSort>(
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
              for (final sort in LinkSort.values)
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
          IconButton(
            tooltip: '添加友链',
            icon: const Icon(Icons.add),
            onPressed: () => _showLinkForm(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PagedListView<Link>(
        value: listState,
        emptyIcon: Icons.link_outlined,
        noItemsMessage: '还没有友情链接',
        onRefresh: () async {
          try {
            await notifier.refresh();
          } on ApiException catch (error) {
            if (context.mounted) showGlobalSnack( error.message, error: true);
          }
        },
        onLoadMore: () => notifier.loadMore(),
        itemBuilder: (context, link) =>
            _LinkTile(link: link, onEdit: () => _showLinkForm(context, ref, link: link)),
      ),
    );
  }

  /// 友链编辑弹层。
  void _showLinkForm(BuildContext context, WidgetRef ref, {Link? link}) {
    final nameController = TextEditingController(text: link?.displayName ?? '');
    final urlController = TextEditingController(text: link?.url ?? '');
    final logoController = TextEditingController(text: link?.logo ?? '');
    final descriptionController =
        TextEditingController(text: link?.description ?? '');
    final remarkController = TextEditingController(text: link?.remark ?? '');
    var priority = link?.priority ?? 0;
    var isLost = link?.isLost ?? false;

    showFormSheet(
      context,
      title: link == null ? '添加友链' : '修改友链',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称'),
              autofocus: link == null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: '链接地址'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: logoController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'LOGO 地址（可选）'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('已失联'),
              value: isLost,
              onChanged: (value) => setState(() => isLost = value),
            ),
            // 优先级滑块
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('优先级'),
              subtitle: Slider(
                value: priority.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$priority',
                onChanged: (value) => setState(() => priority = value.round()),
              ),
              trailing: Text('$priority'),
            ),
          ],
        ),
      ),
      onSave: () async {
        final name = nameController.text.trim();
        final url = urlController.text.trim();
        if (name.isEmpty || url.isEmpty) {
          showGlobalSnack( '名称和链接地址不能为空', error: true);
          return false;
        }
        final api = ref.read(linkApiProvider);
        final body = Link.requestJson(
          linkId: link?.linkId,
          displayName: name,
          url: url,
          logo: logoController.text.trim().isEmpty
              ? null
              : logoController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          priority: priority,
          remark: remarkController.text.trim().isEmpty
              ? null
              : remarkController.text.trim(),
          isLost: isLost,
        );
        try {
          if (link == null) {
            await api.addLink(body);
            showGlobalSnack( '友链已添加');
          } else {
            await api.updateLink(body);
            showGlobalSnack( '友链已保存');
          }
          await ref.read(linkListProvider.notifier).reload();
          return true;
        } on ApiException catch (error) {
          showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }
}

/// 友链列表项。
class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link, required this.onEdit});

  final Link link;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(linkApiProvider);
    final notifier = ref.read(linkListProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        // 点击友链卡片用浏览器打开对应站点
        onTap: () => openExternalUrl(context, link.url),
        leading: link.logo != null && link.logo!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.network(
                    link.logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.link,
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ),
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.link,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                link.displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (link.isLost)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '已失联',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: Text(
                    link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            if (link.description?.isNotEmpty ?? false)
              Text(
                link.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text('优先级 ${link.priority}'),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                onEdit();
              case 'delete':
                final confirmed = await showConfirmDialog(
                  context,
                  title: '删除友链',
                  content: '确定删除「${link.displayName}」吗？',
                  danger: true,
                  confirmText: '删除',
                );
                if (!confirmed) return;
                try {
                  await api.deleteLinks([link.linkId]);
                  if (context.mounted) showGlobalSnack( '友链已删除');
                  await notifier.refresh();
                } on ApiException catch (error) {
                  if (context.mounted) {
                    showGlobalSnack( error.message, error: true);
                  }
                }
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
}
