/// 日记与友情链接模型。
library;

/// 日记，对应后端 `Diary`。
class Diary {
  const Diary({
    required this.diaryId,
    required this.content,
    required this.html,
    required this.createTime,
    this.lastModifyTime,
  });

  final int diaryId;
  final String content;
  final String html;
  final int createTime;
  final int? lastModifyTime;

  factory Diary.fromJson(Map<String, dynamic> json) => Diary(
        diaryId: (json['diaryId'] as num?)?.toInt() ?? -1,
        content: json['content'] as String? ?? '',
        html: json['html'] as String? ?? '',
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );

  /// 新增/修改日记请求体，对应后端 `DiaryRequest`。
  static Map<String, dynamic> requestJson({int? diaryId, required String content}) =>
      {
        'diaryId': ?diaryId,
        'content': content,
      };
}

/// 友情链接，对应后端 `Link`。
class Link {
  const Link({
    required this.linkId,
    required this.displayName,
    required this.url,
    this.logo,
    this.description,
    required this.priority,
    this.remark,
    this.isLost = false,
    required this.createTime,
    this.lastModifyTime,
  });

  final int linkId;
  final String displayName;
  final String url;
  final String? logo;
  final String? description;

  /// 优先级（0 默认，1 - 100）。
  final int priority;
  final String? remark;
  final bool isLost;
  final int createTime;
  final int? lastModifyTime;

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        linkId: (json['linkId'] as num?)?.toInt() ?? -1,
        displayName: json['displayName'] as String? ?? '',
        url: json['url'] as String? ?? '',
        logo: json['logo'] as String?,
        description: json['description'] as String?,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        remark: json['remark'] as String?,
        isLost: json['isLost'] as bool? ?? false,
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        lastModifyTime: (json['lastModifyTime'] as num?)?.toInt(),
      );

  /// 新增/修改友情链接请求体，对应后端 `LinkRequest`。
  static Map<String, dynamic> requestJson({
    int? linkId,
    required String displayName,
    required String url,
    String? logo,
    String? description,
    required int priority,
    String? remark,
    bool isLost = false,
  }) =>
      {
        'linkId': ?linkId,
        'displayName': displayName,
        'url': url,
        'logo': logo,
        'description': description,
        'priority': priority,
        'remark': remark,
        'isLost': isLost,
      };
}
