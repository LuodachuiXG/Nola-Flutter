import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment.dart';
import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_client.dart';

/// 评论 API。
class CommentApi {
  CommentApi(this._client);

  final ApiClient _client;

  /// 分页获取评论。
  Future<Pager<Comment>> comments({
    required int page,
    required int size,
    int? postId,
    int? commentId,
    int? parentId,
    bool? isPass,
    String? key,
    CommentSort? sort,
    bool tree = false,
  }) async {
    return await _client.get<Pager<Comment>>(
      '/admin/comment',
      query: {
        'page': page,
        'size': size,
        'postId': ?postId,
        'commentId': ?commentId,
        'parentCommentId': ?parentId,
        'isPass': ?isPass,
        if (key != null && key.isNotEmpty) 'key': key,
        'sort': ?sort?.json,
        'tree': tree,
      },
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Comment.fromJson,
      ),
    ) as Pager<Comment>;
  }

  /// 管理员添加评论。
  Future<Comment?> addComment(CommentRequest request) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/comment',
      body: request.toJson(),
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : Comment.fromJson(data);
  }

  /// 修改评论。
  Future<bool> updateComment(CommentUpdateRequest request) async {
    return await _client.put<bool>(
          '/admin/comment',
          body: request.toJson(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 设置评论是否通过审核。
  Future<bool> setCommentPass(List<int> ids, bool isPass) async {
    return await _client.put<bool>(
          '/admin/comment/pass',
          body: {'ids': ids, 'isPass': isPass},
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除评论。
  Future<bool> deleteComments(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/comment',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [CommentApi] 提供者。
final commentApiProvider = Provider<CommentApi>((ref) {
  return CommentApi(ref.watch(apiClientProvider));
});
