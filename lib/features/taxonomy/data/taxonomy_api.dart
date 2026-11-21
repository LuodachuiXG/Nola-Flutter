import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/taxonomy.dart';
import '../../../core/network/api_client.dart';

/// 分类与标签 API。
class TaxonomyApi {
  TaxonomyApi(this._client);

  final ApiClient _client;

  // ==================== 分类 ====================

  /// 分页获取分类（page = 0 时获取全部）。
  Future<List<Category>> categories({int page = 0, int size = 0}) async {
    final pager = await _client.get<Pager<Category>>(
      '/admin/category',
      query: {'page': page, 'size': size},
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Category.fromJson,
      ),
    );
    return pager?.data ?? const [];
  }

  /// 添加分类。
  Future<Category?> addCategory(Category category) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/category',
      body: {
        'displayName': category.displayName,
        'slug': category.slug,
        'cover': category.cover,
        'unifiedCover': category.unifiedCover,
      },
      parse: _optionalMap,
    );
    return data == null ? null : Category.fromJson(data);
  }

  /// 修改分类。
  Future<bool> updateCategory(Category category) async {
    return await _client.put<bool>(
          '/admin/category',
          body: {
            'categoryId': category.categoryId,
            'displayName': category.displayName,
            'slug': category.slug,
            'cover': category.cover,
            'unifiedCover': category.unifiedCover,
          },
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 根据分类 ID 集合删除分类。
  Future<bool> deleteCategories(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/category',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 根据分类别名集合删除分类。
  Future<bool> deleteCategoriesBySlugs(List<String> slugs) async {
    return await _client.delete<bool>(
          '/admin/category/slug',
          body: slugs,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  // ==================== 标签 ====================

  /// 分页获取标签（page = 0 时获取全部）。
  Future<List<Tag>> tags({int page = 0, int size = 0}) async {
    final pager = await _client.get<Pager<Tag>>(
      '/admin/tag',
      query: {'page': page, 'size': size},
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Tag.fromJson,
      ),
    );
    return pager?.data ?? const [];
  }

  /// 添加标签。
  Future<Tag?> addTag(Tag tag) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/tag',
      body: {
        'displayName': tag.displayName,
        'slug': tag.slug,
        'color': tag.color,
      },
      parse: _optionalMap,
    );
    return data == null ? null : Tag.fromJson(data);
  }

  /// 修改标签。
  Future<bool> updateTag(Tag tag) async {
    return await _client.put<bool>(
          '/admin/tag',
          body: {
            'tagId': tag.tagId,
            'displayName': tag.displayName,
            'slug': tag.slug,
            'color': tag.color,
          },
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 根据标签 ID 集合删除标签。
  Future<bool> deleteTags(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/tag',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 根据标签别名集合删除标签。
  Future<bool> deleteTagsBySlugs(List<String> slugs) async {
    return await _client.delete<bool>(
          '/admin/tag/slug',
          body: slugs,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

Map<String, dynamic>? _optionalMap(Object? data) =>
    data == null ? null : Map<String, dynamic>.from(data as Map);

/// [TaxonomyApi] 提供者。
final taxonomyApiProvider = Provider<TaxonomyApi>((ref) {
  return TaxonomyApi(ref.watch(apiClientProvider));
});
