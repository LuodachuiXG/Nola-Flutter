/// 菜单模型。
library;

import 'enums.dart';

/// 菜单，对应后端 `Menu`。
class Menu {
  const Menu({
    required this.menuId,
    required this.isMain,
    required this.displayName,
    required this.createTime,
    this.lastModifyTime,
  });

  final int menuId;
  final bool isMain;
  final String displayName;
  final int createTime;
  final int? lastModifyTime;

  factory Menu.fromJson(Map<String, dynamic> json) => Menu(
        menuId: (json['menuId'] as num?)?.toInt() ?? -1,
        isMain: json['isMain'] as bool? ?? false,
        displayName: json['displayName'] as String? ?? '',
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );

  /// 新增/修改菜单请求体，对应后端 `MenuRequest`。
  static Map<String, dynamic> requestJson({
    int? menuId,
    required String displayName,
    required bool isMain,
  }) =>
      {
        'menuId': ?menuId,
        'displayName': displayName,
        'isMain': isMain,
      };
}

/// 菜单项（树形节点），对应后端 `MenuItemResponse`。
class MenuItem {
  const MenuItem({
    required this.menuItemId,
    required this.displayName,
    this.href,
    required this.target,
    required this.parentMenuId,
    this.parentMenuItemId,
    this.children = const [],
    required this.index,
    required this.createTime,
    this.lastModifyTime,
  });

  final int menuItemId;
  final String displayName;
  final String? href;
  final MenuItemTarget target;
  final int parentMenuId;
  final int? parentMenuItemId;
  final List<MenuItem> children;
  final int index;
  final int createTime;
  final int? lastModifyTime;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        menuItemId: (json['menuItemId'] as num?)?.toInt() ?? -1,
        displayName: json['displayName'] as String? ?? '',
        href: json['href'] as String?,
        target: parseEnum(
          MenuItemTarget.values,
          json['target'] as String?,
          MenuItemTarget.blank,
        ),
        parentMenuId: (json['parentMenuId'] as num?)?.toInt() ?? -1,
        parentMenuItemId: (json['parentMenuItemId'] as num?)?.toInt(),
        children: (json['children'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((c) => MenuItem.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        index: (json['index'] as num?)?.toInt() ?? 0,
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );

  /// 新增/修改菜单项请求体，对应后端 `MenuItemRequest`。
  static Map<String, dynamic> requestJson({
    int? menuItemId,
    required String displayName,
    required String href,
    required MenuItemTarget target,
    required int parentMenuId,
    int? parentMenuItemId,
    required int index,
  }) =>
      {
        'menuItemId': ?menuItemId,
        'displayName': displayName,
        'href': href,
        'target': target.json,
        'parentMenuId': parentMenuId,
        'parentMenuItemId': parentMenuItemId,
        'index': index,
      };
}
