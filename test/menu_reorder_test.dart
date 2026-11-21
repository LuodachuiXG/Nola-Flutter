import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/models/enums.dart';
import 'package:nola/core/models/menu.dart';
import 'package:nola/core/network/api_client.dart';
import 'package:nola/features/menus/data/menu_api.dart';
import 'package:nola/features/menus/ui/menu_screen.dart';

/// 内存版菜单 API：记录增改调用并应用 index 变更。
class FakeMenuApi extends MenuApi {
  FakeMenuApi() : super(ApiClient(Dio()));

  final List<Map<String, dynamic>> updateCalls = [];
  final List<Map<String, dynamic>> addCalls = [];

  final List<MenuItem> _items = [
    const MenuItem(
      menuItemId: 1,
      displayName: '首页',
      href: '/',
      target: MenuItemTarget.self,
      parentMenuId: 1,
      index: 0,
      createTime: 0,
    ),
    const MenuItem(
      menuItemId: 2,
      displayName: '归档',
      href: '/archives',
      target: MenuItemTarget.self,
      parentMenuId: 1,
      index: 1,
      createTime: 0,
    ),
    const MenuItem(
      menuItemId: 3,
      displayName: '友情链接',
      href: '/links',
      target: MenuItemTarget.self,
      parentMenuId: 1,
      index: 2,
      createTime: 0,
    ),
    const MenuItem(
      menuItemId: 5,
      displayName: '关于我',
      href: '/about',
      target: MenuItemTarget.self,
      parentMenuId: 1,
      index: 3,
      createTime: 0,
    ),
  ];

  List<MenuItem> get topLevel => _items
      .where((item) => item.parentMenuItemId == null)
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  @override
  Future<List<Menu>> menus({int page = 0, int size = 0}) async {
    return [
      const Menu(
        menuId: 1,
        isMain: true,
        displayName: '主菜单',
        createTime: 0,
      ),
    ];
  }

  @override
  Future<List<MenuItem>> menuItems(int menuId, {bool tree = true}) async {
    final result = <MenuItem>[];
    for (final top in topLevel) {
      final children = _items
          .where((item) => item.parentMenuItemId == top.menuItemId)
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      result.add(
        MenuItem(
          menuItemId: top.menuItemId,
          displayName: top.displayName,
          href: top.href,
          target: top.target,
          parentMenuId: top.parentMenuId,
          parentMenuItemId: top.parentMenuItemId,
          children: children,
          index: top.index,
          createTime: top.createTime,
        ),
      );
    }
    return result;
  }

  @override
  Future<bool> updateMenuItem(Map<String, dynamic> body) async {
    updateCalls.add(body);
    final id = body['menuItemId'] as int;
    final old = _items.firstWhere((item) => item.menuItemId == id);
    _items[_items.indexOf(old)] = MenuItem(
      menuItemId: id,
      displayName: body['displayName'] as String? ?? old.displayName,
      href: body['href'] as String?,
      target: parseEnum(
        MenuItemTarget.values,
        body['target'] as String?,
        MenuItemTarget.blank,
      ),
      parentMenuId:
          (body['parentMenuId'] as num?)?.toInt() ?? old.parentMenuId,
      parentMenuItemId: (body['parentMenuItemId'] as num?)?.toInt(),
      children: old.children,
      index: (body['index'] as num?)?.toInt() ?? old.index,
      createTime: old.createTime,
    );
    return true;
  }

  @override
  Future<MenuItem?> addMenuItem(Map<String, dynamic> body) async {
    addCalls.add(body);
    final item = MenuItem(
      menuItemId:
          _items.map((i) => i.menuItemId).reduce((a, b) => a > b ? a : b) + 1,
      displayName: body['displayName'] as String? ?? '',
      href: body['href'] as String?,
      target: parseEnum(
        MenuItemTarget.values,
        body['target'] as String?,
        MenuItemTarget.blank,
      ),
      parentMenuId: (body['parentMenuId'] as num?)?.toInt() ?? 1,
      parentMenuItemId: (body['parentMenuItemId'] as num?)?.toInt(),
      index: (body['index'] as num?)?.toInt() ?? 0,
      createTime: 0,
    );
    _items.add(item);
    return item;
  }
}

/// 菜单项排序回归测试：上移 / 下移自动计算 index 并持久化。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMenuScreen(WidgetTester tester, FakeMenuApi api) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: MenuScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('下移菜单项：同级 index 重编为 0..n-1 并持久化', (tester) async {
    final api = FakeMenuApi();
    await pumpMenuScreen(tester, api);

    // 打开「首页」（第一个菜单项）的操作菜单，点击「下移」
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下移'));
    await tester.pumpAndSettle();

    // 新顺序：归档 / 首页 / 友情链接 / 关于我
    final orderedNames = api.topLevel.map((item) => item.displayName).toList();
    expect(orderedNames, ['归档', '首页', '友情链接', '关于我']);

    // 全部同级项的 index 已重编为 0..n-1 并保存
    expect(api.updateCalls.length, 4);
    final indexById = {
      for (final call in api.updateCalls)
        call['menuItemId'] as int: call['index'] as int,
    };
    expect(indexById[2], 0); // 归档
    expect(indexById[1], 1); // 首页
    expect(indexById[3], 2); // 友情链接
    expect(indexById[5], 3); // 关于我
  });

  testWidgets('首项的上移与末项的下移不可用', (tester) async {
    final api = FakeMenuApi();
    await pumpMenuScreen(tester, api);

    // 首页（第一个菜单项）：「上移」不可用
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, '上移'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, '下移'),
          )
          .enabled,
      isTrue,
    );
    // 关闭菜单
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 关于我（最后一个菜单项）：「下移」不可用
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, '下移'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, '上移'),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('新建菜单项自动追加到同级末尾（无需手输 index）', (tester) async {
    final api = FakeMenuApi();
    await pumpMenuScreen(tester, api);

    // 打开添加表单并填写名称
    await tester.tap(find.text('添加菜单项'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '新页面');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 新菜单项的 index 自动为同级最大值 + 1（追加到末尾）
    expect(api.addCalls.length, 1);
    expect(api.addCalls.first['index'], 4);
    expect(api.addCalls.first['displayName'], '新页面');
    expect(api.addCalls.first['parentMenuItemId'], isNull);
  });

  testWidgets('子菜单项下移按同级重编 index', (tester) async {
    final api = FakeMenuApi();
    api._items.addAll([
      const MenuItem(
        menuItemId: 4,
        displayName: '友链申请',
        href: '/links/apply',
        target: MenuItemTarget.self,
        parentMenuId: 1,
        parentMenuItemId: 3,
        index: 0,
        createTime: 0,
      ),
      const MenuItem(
        menuItemId: 6,
        displayName: '友链列表',
        href: '/links/list',
        target: MenuItemTarget.self,
        parentMenuId: 1,
        parentMenuItemId: 3,
        index: 1,
        createTime: 0,
      ),
    ]);
    await pumpMenuScreen(tester, api);

    // 展开「友情链接」
    await tester.tap(find.text('友情链接'));
    await tester.pumpAndSettle();
    expect(find.text('友链申请'), findsOneWidget);

    // 打开「友链申请」自己的操作菜单，点击「下移」
    final childTile = find.ancestor(
      of: find.text('友链申请'),
      matching: find.byType(ListTile),
    );
    final childMenu = find.descendant(
      of: childTile.first,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.tap(childMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下移'));
    await tester.pumpAndSettle();

    // 子项 index 已重编并保存
    final callsForChildren = api.updateCalls
        .where((call) => call['parentMenuItemId'] == 3)
        .toList();
    expect(callsForChildren.length, 2);
    final indexById = {
      for (final call in callsForChildren)
        call['menuItemId'] as int: call['index'] as int,
    };
    expect(indexById[6], 0); // 友链列表
    expect(indexById[4], 1); // 友链申请
  });
}
