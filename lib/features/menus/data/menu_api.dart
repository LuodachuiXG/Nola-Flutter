import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/menu.dart';
import '../../../core/network/api_client.dart';

/// 菜单 API。
class MenuApi {
  MenuApi(this._client);

  final ApiClient _client;

  /// 分页获取菜单（page = 0 获取全部）。
  Future<List<Menu>> menus({int page = 0, int size = 0}) async {
    final pager = await _client.get<Pager<Menu>>(
      '/admin/menu',
      query: {'page': page, 'size': size},
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Menu.fromJson,
      ),
    );
    return pager?.data ?? const [];
  }

  /// 添加菜单。
  Future<Menu?> addMenu({
    required String displayName,
    required bool isMain,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/menu',
      body: Menu.requestJson(displayName: displayName, isMain: isMain),
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : Menu.fromJson(data);
  }

  /// 修改菜单。
  Future<bool> updateMenu({
    required int menuId,
    required String displayName,
    required bool isMain,
  }) async {
    return await _client.put<bool>(
          '/admin/menu',
          body: Menu.requestJson(
            menuId: menuId,
            displayName: displayName,
            isMain: isMain,
          ),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除菜单。
  Future<bool> deleteMenus(List<int> menuIds) async {
    return await _client.delete<bool>(
          '/admin/menu',
          body: menuIds,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 获取菜单项（可构建树形结构）。
  Future<List<MenuItem>> menuItems(int menuId, {bool tree = true}) async {
    final data = await _client.get<List<dynamic>>(
      '/admin/menu/item/$menuId',
      query: {'tree': tree},
      parse: (data) => data as List<dynamic>? ?? [],
    );
    return (data ?? [])
        .whereType<Map>()
        .map((item) => MenuItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// 添加菜单项。
  Future<MenuItem?> addMenuItem(Map<String, dynamic> body) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/menu/item',
      body: body,
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : MenuItem.fromJson(data);
  }

  /// 修改菜单项。
  Future<bool> updateMenuItem(Map<String, dynamic> body) async {
    return await _client.put<bool>(
          '/admin/menu/item',
          body: body,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除菜单项。
  Future<bool> deleteMenuItems(List<int> menuItemIds) async {
    return await _client.delete<bool>(
          '/admin/menu/item',
          body: menuItemIds,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [MenuApi] 提供者。
final menuApiProvider = Provider<MenuApi>((ref) {
  return MenuApi(ref.watch(apiClientProvider));
});
