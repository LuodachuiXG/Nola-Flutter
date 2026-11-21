import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/menu.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../shell/ui/console_shell.dart';
import '../data/menu_api.dart';
import '../providers/menu_providers.dart';

/// 菜单管理页：上方切换菜单，下方管理菜单项树。
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  int? _selectedMenuId;

  @override
  Widget build(BuildContext context) {
    final menus = ref.watch(menuListProvider);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '菜单',
        actions: [
          IconButton(
            tooltip: '新建菜单',
            icon: const Icon(Icons.add),
            onPressed: () => _showMenuForm(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncValueWidget<List<Menu>>(
        value: menus,
        builder: (context, data) {
          if (data.isEmpty) {
            return const EmptyPlaceholder(
              icon: Icons.menu_open_outlined,
              message: '还没有菜单，点击右上角创建',
            );
          }
          // 默认选中第一个菜单
          if (_selectedMenuId == null ||
              !data.any((menu) => menu.menuId == _selectedMenuId)) {
            _selectedMenuId = data.first.menuId;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 菜单选择条
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    for (final menu in data)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(menu.displayName),
                              if (menu.isMain) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          selected: menu.menuId == _selectedMenuId,
                          onSelected: (_) =>
                              setState(() => _selectedMenuId = menu.menuId),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _MenuItemsPanel(menuId: _selectedMenuId!),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 新建 / 修改菜单表单。
  void _showMenuForm(BuildContext context, WidgetRef ref, {Menu? menu}) {
    final nameController =
        TextEditingController(text: menu?.displayName ?? '');
    var isMain = menu?.isMain ?? false;

    showFormSheet(
      context,
      title: menu == null ? '新建菜单' : '修改菜单',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '菜单名称'),
              autofocus: menu == null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('设为主菜单'),
              subtitle: const Text('前台默认展示主菜单'),
              value: isMain,
              onChanged: (value) => setState(() => isMain = value),
            ),
          ],
        ),
      ),
      onSave: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          showGlobalSnack( '菜单名称不能为空', error: true);
          return false;
        }
        final api = ref.read(menuApiProvider);
        try {
          if (menu == null) {
            await api.addMenu(displayName: name, isMain: isMain);
            showGlobalSnack( '菜单已创建');
          } else {
            await api.updateMenu(
              menuId: menu.menuId,
              displayName: name,
              isMain: isMain,
            );
            showGlobalSnack( '菜单已保存');
          }
          ref.invalidate(menuListProvider);
          return true;
        } on ApiException catch (error) {
          showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }
}

/// 菜单项面板。
class _MenuItemsPanel extends ConsumerWidget {
  const _MenuItemsPanel({required this.menuId});

  final int menuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(menuItemsProvider(menuId));
    final theme = Theme.of(context);

    return AsyncValueWidget<List<MenuItem>>(
      value: items,
      builder: (context, data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    '菜单项',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => showMenuItemForm(context, ref, menuId),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加菜单项'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.isEmpty
                  ? const EmptyPlaceholder(
                      icon: Icons.format_list_bulleted,
                      message: '暂无菜单项',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(menuItemsProvider(menuId)),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final item in data)
                            _MenuItemNode(node: item, menuId: menuId),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 菜单项树节点。
class _MenuItemNode extends ConsumerWidget {
  const _MenuItemNode({required this.node, required this.menuId});

  final MenuItem node;
  final int menuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                node.displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'index ${node.index}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${node.href ?? ''} · ${node.target.label}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    final children = node.children;
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: title,
            trailing: _NodeMenu(node: node, menuId: menuId),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
            title: title,
            trailing: _NodeMenu(node: node, menuId: menuId),
            children: [
              for (final child in children)
                _MenuItemNode(node: child, menuId: menuId),
            ],
          ),
        ),
      ),
    );
  }
}

/// 节点操作菜单。
class _NodeMenu extends ConsumerWidget {
  const _NodeMenu({required this.node, required this.menuId});

  final MenuItem node;
  final int menuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'add_child':
            await showMenuItemForm(context, ref, menuId, parent: node);
          case 'edit':
            await showMenuItemForm(context, ref, menuId, item: node);
          case 'delete':
            await _delete(context, ref);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'add_child',
          child: ListTile(
            leading: Icon(Icons.subdirectory_arrow_right),
            title: Text('添加子项'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
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
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除菜单项',
      content: '确定删除菜单项「${node.displayName}」及其子项吗？',
      danger: true,
      confirmText: '删除',
    );
    if (!confirmed) return;
    try {
      await ref.read(menuApiProvider).deleteMenuItems([node.menuItemId]);
      ref.invalidate(menuItemsProvider(menuId));
      if (context.mounted) showGlobalSnack( '菜单项已删除');
    } on ApiException catch (error) {
      if (context.mounted) showGlobalSnack( error.message, error: true);
    }
  }
}

/// 展开树节点为一维列表（父级选项用）。
List<MenuItem> _flatten(List<MenuItem> nodes) {
  return [
    for (final node in nodes) ...[
      node,
      ..._flatten(node.children),
    ],
  ];
}

/// 新建 / 修改菜单项表单。
Future<void> showMenuItemForm(
  BuildContext context,
  WidgetRef ref,
  int menuId, {
  MenuItem? item,
  MenuItem? parent,
}) async {
  final nameController = TextEditingController(text: item?.displayName ?? '');
  final hrefController = TextEditingController(text: item?.href ?? '');
  var target = item?.target ?? MenuItemTarget.blank;
  var parentMenuItemId = item?.parentMenuItemId ?? parent?.menuItemId;
  final indexController = TextEditingController(
    text: '${item?.index ?? 0}',
  );

  // 获取全部菜单项供选择父级
  final allItems = await ref.read(menuApiProvider).menuItems(menuId);
  if (!context.mounted) return;

  await showFormSheet(
    context,
    title: item == null ? '添加菜单项' : '修改菜单项',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '名称'),
            autofocus: item == null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: hrefController,
            decoration: const InputDecoration(labelText: '链接地址'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MenuItemTarget>(
            initialValue: target,
            decoration: const InputDecoration(labelText: '打开方式'),
            items: [
              for (final value in MenuItemTarget.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) => setState(() => target = value ?? target),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: parentMenuItemId,
            decoration: const InputDecoration(labelText: '父级菜单项'),
            items: [
              const DropdownMenuItem(value: null, child: Text('顶级')),
              for (final candidate in _flatten(allItems))
                if (candidate.menuItemId != item?.menuItemId)
                  DropdownMenuItem(
                    value: candidate.menuItemId,
                    child: Text(candidate.displayName),
                  ),
            ],
            onChanged: (value) => setState(() => parentMenuItemId = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: indexController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '排序索引'),
          ),
        ],
      ),
    ),
    onSave: () async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        showGlobalSnack( '名称不能为空', error: true);
        return false;
      }
      final index = int.tryParse(indexController.text.trim()) ?? 0;
      final body = MenuItem.requestJson(
        menuItemId: item?.menuItemId,
        displayName: name,
        href: hrefController.text.trim(),
        target: target,
        parentMenuId: menuId,
        parentMenuItemId: parentMenuItemId,
        index: index,
      );
      final api = ref.read(menuApiProvider);
      try {
        if (item == null) {
          await api.addMenuItem(body);
          showGlobalSnack( '菜单项已添加');
        } else {
          await api.updateMenuItem(body);
          showGlobalSnack( '菜单项已保存');
        }
        ref.invalidate(menuItemsProvider(menuId));
        return true;
      } on ApiException catch (error) {
        showGlobalSnack( error.message, error: true);
        return false;
      }
    },
  );
}
