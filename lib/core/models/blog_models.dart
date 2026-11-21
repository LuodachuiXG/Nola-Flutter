/// 博客信息、备案与概览模型。
library;

import 'post.dart';
import 'taxonomy.dart';

/// 博客信息，对应后端 `BlogInfo`。
class BlogInfo {
  const BlogInfo({
    required this.title,
    this.subtitle,
    this.blogger,
    this.logo,
    this.favicon,
    this.createDate,
  });

  final String? title;
  final String? subtitle;
  final String? blogger;
  final String? logo;
  final String? favicon;
  final int? createDate;

  /// 博客是否已初始化。
  bool get initialized => title != null;

  factory BlogInfo.fromJson(Map<String, dynamic> json) => BlogInfo(
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        blogger: json['blogger'] as String?,
        logo: json['logo'] as String?,
        favicon: json['favicon'] as String?,
        createDate: (json['createDate'] as num?)?.toInt(),
      );

  /// 初始化博客请求体。
  static Map<String, dynamic> initJson({
    required String title,
    String? subtitle,
  }) =>
      {
        'title': title,
        'subtitle': subtitle,
      };

  /// 修改博客信息请求体，对应后端 `BlogInfoRequest`。
  static Map<String, dynamic> updateJson({
    required String title,
    String? subtitle,
    String? logo,
    String? favicon,
  }) =>
      {
        'title': title,
        'subtitle': subtitle,
        'logo': logo,
        'favicon': favicon,
      };
}

/// ICP 备案信息，对应后端 `ICPFiling`。
class ICPFiling {
  const ICPFiling({this.icp, this.police});

  final String? icp;
  final String? police;

  factory ICPFiling.fromJson(Map<String, dynamic> json) => ICPFiling(
        icp: json['icp'] as String?,
        police: json['police'] as String?,
      );

  Map<String, dynamic> toJson() => {'icp': icp, 'police': police};
}

/// 概览数量统计，对应后端 `OverviewCount`。
class OverviewCount {
  const OverviewCount({
    required this.post,
    required this.tag,
    required this.category,
    required this.comment,
    required this.diary,
    required this.file,
    required this.link,
    required this.menu,
  });

  final int post;
  final int tag;
  final int category;
  final int comment;
  final int diary;
  final int file;
  final int link;
  final int menu;

  factory OverviewCount.fromJson(Map<String, dynamic> json) => OverviewCount(
        post: (json['post'] as num?)?.toInt() ?? 0,
        tag: (json['tag'] as num?)?.toInt() ?? 0,
        category: (json['category'] as num?)?.toInt() ?? 0,
        comment: (json['comment'] as num?)?.toInt() ?? 0,
        diary: (json['diary'] as num?)?.toInt() ?? 0,
        file: (json['file'] as num?)?.toInt() ?? 0,
        link: (json['link'] as num?)?.toInt() ?? 0,
        menu: (json['menu'] as num?)?.toInt() ?? 0,
      );
}

/// 博客概览，对应后端 `OverviewResponse`。
class Overview {
  const Overview({
    required this.postVisitCount,
    required this.count,
    required this.tags,
    required this.categories,
    this.mostViewedPost,
    this.lastOperation,
    this.lastLoginDate,
    this.createDate,
  });

  final int postVisitCount;
  final OverviewCount count;
  final List<Tag> tags;
  final List<Category> categories;
  final Post? mostViewedPost;
  final String? lastOperation;
  final int? lastLoginDate;
  final int? createDate;

  factory Overview.fromJson(Map<String, dynamic> json) => Overview(
        postVisitCount: (json['postVisitCount'] as num?)?.toInt() ?? 0,
        count: json['count'] is Map
            ? OverviewCount.fromJson(Map<String, dynamic>.from(json['count']))
            : const OverviewCount(
                post: 0,
                tag: 0,
                category: 0,
                comment: 0,
                diary: 0,
                file: 0,
                link: 0,
                menu: 0,
              ),
        tags: (json['tags'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((t) => Tag.fromJson(Map<String, dynamic>.from(t)))
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        mostViewedPost: json['mostViewedPost'] is Map
            ? Post.fromJson(
                Map<String, dynamic>.from(json['mostViewedPost']),
              )
            : null,
        lastOperation: json['lastOperation'] as String?,
        lastLoginDate: (json['lastLoginDate'] as num?)?.toInt(),
        createDate: (json['createDate'] as num?)?.toInt(),
      );
}

/// SSE 在线人数事件，对应后端 `OnlineCount`。
class OnlineCount {
  const OnlineCount({required this.count, required this.timestamp});

  final int count;
  final int timestamp;

  factory OnlineCount.fromJson(Map<String, dynamic> json) => OnlineCount(
        count: (json['count'] as num?)?.toInt() ?? 0,
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
}
