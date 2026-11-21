/// 分类与标签模型。
library;

/// 文章分类，对应后端 `Category`。
class Category {
  const Category({
    required this.categoryId,
    required this.displayName,
    required this.slug,
    this.cover,
    this.unifiedCover = false,
    this.postCount,
  });

  final int categoryId;
  final String displayName;
  final String slug;
  final String? cover;
  final bool unifiedCover;
  final int? postCount;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        categoryId: (json['categoryId'] as num?)?.toInt() ?? -1,
        displayName: json['displayName'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        cover: json['cover'] as String?,
        unifiedCover: json['unifiedCover'] as bool? ?? false,
        postCount: (json['postCount'] as num?)?.toInt(),
      );

  /// 新建/修改分类的请求体（与后端 `Category` 结构一致）。
  Map<String, dynamic> toJson({
    int? categoryId,
    required String displayName,
    required String slug,
    String? cover,
    required bool unifiedCover,
  }) =>
      {
        'categoryId': categoryId ?? this.categoryId,
        'displayName': displayName,
        'slug': slug,
        'cover': cover,
        'unifiedCover': unifiedCover,
      };
}

/// 文章标签，对应后端 `Tag`。
class Tag {
  const Tag({
    required this.tagId,
    required this.displayName,
    required this.slug,
    this.color,
    this.postCount,
  });

  final int tagId;
  final String displayName;
  final String slug;

  /// 标签颜色（十六进制字符串，如 `#3FB27F`）。
  final String? color;
  final int? postCount;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        tagId: (json['tagId'] as num?)?.toInt() ?? -1,
        displayName: json['displayName'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        color: json['color'] as String?,
        postCount: (json['postCount'] as num?)?.toInt(),
      );

  /// 新建/修改标签的请求体（与后端 `Tag` 结构一致）。
  Map<String, dynamic> toJson({
    int? tagId,
    required String displayName,
    required String slug,
    String? color,
  }) =>
      {
        'tagId': tagId ?? this.tagId,
        'displayName': displayName,
        'slug': slug,
        'color': color,
      };
}
