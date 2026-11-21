import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/taxonomy.dart';
import '../data/taxonomy_api.dart';

/// 分类列表状态管理。
class CategoryListNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    return ref.watch(taxonomyApiProvider).categories();
  }

  /// 重新加载。
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(taxonomyApiProvider).categories(),
    );
  }
}

/// 分类列表提供者。
final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<Category>>(
  CategoryListNotifier.new,
);

/// 标签列表状态管理。
class TagListNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() {
    return ref.watch(taxonomyApiProvider).tags();
  }

  /// 重新加载。
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(taxonomyApiProvider).tags(),
    );
  }
}

/// 标签列表提供者。
final tagListProvider =
    AsyncNotifierProvider<TagListNotifier, List<Tag>>(TagListNotifier.new);
