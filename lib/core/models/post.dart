/// 文章相关模型。
library;

import 'enums.dart';
import 'taxonomy.dart';

/// 文章，对应后端 `Post`。
class Post {
  const Post({
    required this.postId,
    required this.title,
    required this.autoGenerateExcerpt,
    required this.excerpt,
    required this.slug,
    this.cover,
    required this.allowComment,
    this.pinned,
    required this.status,
    required this.visible,
    required this.encrypted,
    this.password,
    required this.visit,
    this.category,
    required this.tags,
    required this.createTime,
    this.lastModifyTime,
  });

  final int postId;
  final String title;
  final bool autoGenerateExcerpt;
  final String excerpt;
  final String slug;
  final String? cover;
  final bool allowComment;
  final bool? pinned;
  final PostStatus status;
  final PostVisible visible;
  final bool encrypted;
  final String? password;
  final int visit;
  final Category? category;
  final List<Tag> tags;
  final int createTime;
  final int? lastModifyTime;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        postId: (json['postId'] as num?)?.toInt() ?? -1,
        title: json['title'] as String? ?? '',
        autoGenerateExcerpt: json['autoGenerateExcerpt'] as bool? ?? true,
        excerpt: json['excerpt'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        cover: json['cover'] as String?,
        allowComment: json['allowComment'] as bool? ?? true,
        pinned: json['pinned'] as bool?,
        status: parseEnum(
          PostStatus.values,
          json['status'] as String?,
          PostStatus.draft,
        ),
        visible: parseEnum(
          PostVisible.values,
          json['visible'] as String?,
          PostVisible.visible,
        ),
        encrypted: json['encrypted'] as bool? ?? false,
        password: json['password'] as String?,
        visit: (json['visit'] as num?)?.toInt() ?? 0,
        category: json['category'] is Map
            ? Category.fromJson(Map<String, dynamic>.from(json['category']))
            : null,
        tags: (json['tags'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((t) => Tag.fromJson(Map<String, dynamic>.from(t)))
            .toList(),
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );

  /// 修改文章状态请求体，对应后端 `PostStatusRequest`。
  static Map<String, dynamic> statusRequestJson({
    required int postId,
    PostStatus? status,
    PostVisible? visible,
    bool? pinned,
  }) =>
      {
        'postId': postId,
        'status': status?.json,
        'visible': visible?.json,
        'pinned': pinned,
      };
}

/// 新建/修改文章请求体，对应后端 `PostRequest`。
class PostRequest {
  const PostRequest({
    this.postId,
    required this.title,
    required this.autoGenerateExcerpt,
    this.excerpt,
    required this.slug,
    required this.allowComment,
    required this.status,
    required this.visible,
    this.content,
    this.categoryId,
    this.tagIds,
    this.cover,
    this.pinned = false,
    this.encrypted,
    this.password,
  });

  /// 文章 ID，新建时为 null。
  final int? postId;
  final String title;
  final bool autoGenerateExcerpt;
  final String? excerpt;
  final String slug;
  final bool allowComment;
  final PostStatus status;
  final PostVisible visible;

  /// 文章内容（Markdown 或普通文本），不修改时为 null。
  final String? content;
  final int? categoryId;
  final List<int>? tagIds;
  final String? cover;
  final bool pinned;

  /// 文章加密：true 需同时提供密码；null 保持不变；false 删除密码。
  final bool? encrypted;
  final String? password;

  Map<String, dynamic> toJson() => {
        if (postId != null) 'postId': postId,
        'title': title,
        'autoGenerateExcerpt': autoGenerateExcerpt,
        'excerpt': excerpt,
        'slug': slug,
        'allowComment': allowComment,
        'status': status.json,
        'visible': visible.json,
        'content': content,
        'categoryId': categoryId,
        'tagIds': tagIds,
        'cover': cover,
        'pinned': pinned,
        'encrypted': encrypted,
        'password': password,
      };
}

/// 文章内容（正文或草稿），对应后端 `PostContent`。
class PostContent {
  const PostContent({
    required this.postContentId,
    required this.postId,
    required this.content,
    required this.html,
    required this.status,
    this.draftName,
    this.lastModifyTime,
  });

  final int postContentId;
  final int postId;

  /// Markdown 或普通文本内容。
  final String content;

  /// 服务端解析后的 HTML。
  final String html;
  final PostContentStatus status;
  final String? draftName;
  final int? lastModifyTime;

  factory PostContent.fromJson(Map<String, dynamic> json) => PostContent(
        postContentId: (json['postContentId'] as num?)?.toInt() ?? -1,
        postId: (json['postId'] as num?)?.toInt() ?? -1,
        content: json['content'] as String? ?? '',
        html: json['html'] as String? ?? '',
        status: parseEnum(
          PostContentStatus.values,
          json['status'] as String?,
          PostContentStatus.published,
        ),
        draftName: json['draftName'] as String?,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );
}

/// 文章内容元信息（不含正文），对应后端 `PostContentResponse`。
class PostContentMeta {
  const PostContentMeta({
    required this.postContentId,
    required this.postId,
    required this.status,
    this.draftName,
    this.lastModifyTime,
  });

  final int postContentId;
  final int postId;
  final PostContentStatus status;
  final String? draftName;
  final int? lastModifyTime;

  factory PostContentMeta.fromJson(Map<String, dynamic> json) =>
      PostContentMeta(
        postContentId: (json['postContentId'] as num?)?.toInt() ?? -1,
        postId: (json['postId'] as num?)?.toInt() ?? -1,
        status: parseEnum(
          PostContentStatus.values,
          json['status'] as String?,
          PostContentStatus.published,
        ),
        draftName: json['draftName'] as String?,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );
}
