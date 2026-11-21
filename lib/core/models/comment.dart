/// 评论模型。
library;

/// 评论，对应后端 `Comment`（树形结构时包含 [children]）。
class Comment {
  const Comment({
    required this.commentId,
    required this.postId,
    this.postTitle,
    this.parentCommentId,
    this.replyCommentId,
    this.replyDisplayName,
    required this.content,
    this.site,
    required this.displayName,
    required this.email,
    required this.createTime,
    required this.isPass,
    this.children,
  });

  final int commentId;
  final int postId;
  final String? postTitle;
  final int? parentCommentId;
  final int? replyCommentId;
  final String? replyDisplayName;
  final String content;
  final String? site;
  final String displayName;
  final String email;
  final int createTime;
  final bool isPass;
  final List<Comment>? children;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        commentId: (json['commentId'] as num?)?.toInt() ?? -1,
        postId: (json['postId'] as num?)?.toInt() ?? -1,
        postTitle: json['postTitle'] as String?,
        parentCommentId: (json['parentCommentId'] as num?)?.toInt(),
        replyCommentId: (json['replyCommentId'] as num?)?.toInt(),
        replyDisplayName: json['replyDisplayName'] as String?,
        content: json['content'] as String? ?? '',
        site: json['site'] as String?,
        displayName: json['displayName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
        isPass: json['isPass'] as bool? ?? false,
        children: (json['children'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((c) => Comment.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );
}

/// 新增评论请求体，对应后端 `CommentRequest`。
class CommentRequest {
  const CommentRequest({
    required this.postId,
    this.parentCommentId,
    this.replyCommentId,
    required this.content,
    this.site,
    required this.displayName,
    required this.email,
    this.isPass = false,
  });

  final int postId;
  final int? parentCommentId;
  final int? replyCommentId;
  final String content;
  final String? site;
  final String displayName;
  final String email;
  final bool isPass;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'parentCommentId': parentCommentId,
        'replyCommentId': replyCommentId,
        'content': content,
        'site': site,
        'displayName': displayName,
        'email': email,
        'isPass': isPass,
      };
}

/// 修改评论请求体，对应后端 `CommentUpdateRequest`。
class CommentUpdateRequest {
  const CommentUpdateRequest({
    required this.commentId,
    required this.content,
    this.site,
    required this.displayName,
    required this.email,
    required this.isPass,
  });

  final int commentId;
  final String content;
  final String? site;
  final String displayName;
  final String email;
  final bool isPass;

  Map<String, dynamic> toJson() => {
        'commentId': commentId,
        'content': content,
        'site': site,
        'displayName': displayName,
        'email': email,
        'isPass': isPass,
      };
}
