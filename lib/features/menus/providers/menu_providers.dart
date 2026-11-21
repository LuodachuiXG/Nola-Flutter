import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/menu.dart';
import '../data/menu_api.dart';

/// 菜单列表。
final menuListProvider = FutureProvider.autoDispose<List<Menu>>((ref) {
  return ref.watch(menuApiProvider).menus();
});

/// 指定菜单的菜单项树。
final menuItemsProvider =
    FutureProvider.autoDispose.family<List<MenuItem>, int>((ref, menuId) {
  return ref.watch(menuApiProvider).menuItems(menuId);
});
