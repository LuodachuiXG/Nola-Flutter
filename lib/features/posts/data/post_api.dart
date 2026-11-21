import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/post.dart';
import '../../../core/network/api_client.dart';

/// 文章 API。
class PostApi {
  PostApi(this._client);

  final ApiClient _client;

  /// 分页获取文章。
  ///
  /// [status] 为 null 时查询全部非回收站文章。
  Future<Pager<Post>> posts({
    required int page,
    required int size,
    PostStatus? status,
    PostVisible? visible,
    String? key,
    int? tagId,
    int? categoryId,
    PostSort? sort,
  }) async {
    return await _client.get<Pager<Post>>(
      '/admin/post',
      query: {
        'page': page,
        'size': size,
        'status': ?status?.json,
        'visible': ?visible?.json,
        if (key != null && key.isNotEmpty) 'key': key,
        'tag': ?tagId,
        'category': ?categoryId,
        'sort': ?sort?.json,
      },
      parse: (data) =>
          Pager.fromJson(Map<String, dynamic>.from(data as Map), Post.fromJson),
    ) as Pager<Post>;
  }

  /// 根据文章 ID 获取文章。
  Future<Post?> post(int postId) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/post/$postId',
      parse: _optionalMap,
    );
    return data == null ? null : Post.fromJson(data);
  }

  /// 添加文章。
  Future<Post?> addPost(PostRequest request) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/post',
      body: request.toJson(),
      parse: _optionalMap,
    );
    return data == null ? null : Post.fromJson(data);
  }

  /// 修改文章。
  Future<bool> updatePost(PostRequest request) async {
    return await _client.put<bool>(
          '/admin/post',
          body: request.toJson(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 修改文章状态（状态 / 可见性 / 置顶）。
  Future<bool> updatePostStatus({
    required int postId,
    PostStatus? status,
    PostVisible? visible,
    bool? pinned,
  }) async {
    return await _client.put<bool>(
          '/admin/post/status',
          body: Post.statusRequestJson(
            postId: postId,
            status: status,
            visible: visible,
            pinned: pinned,
          ),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 回收文章（放入回收站）。
  Future<bool> recyclePosts(List<int> postIds) async {
    return await _client.put<bool>(
          '/admin/post/recycle',
          body: postIds,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 从回收站恢复文章到指定状态。
  Future<bool> restorePosts(List<int> postIds, PostStatus status) async {
    return await _client.put<bool>(
          '/admin/post/restore/${status.json}',
          body: postIds,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 彻底删除文章（仅回收站文章可删除）。
  Future<bool> deletePosts(List<int> postIds) async {
    return await _client.delete<bool>(
          '/admin/post',
          body: postIds,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 获取文章的所有内容（正文元信息 + 草稿元信息）。
  Future<List<PostContentMeta>> postContents(int postId) async {
    final data = await _client.get<List<dynamic>>(
      '/admin/post/content/$postId',
      parse: (data) => data as List<dynamic>? ?? [],
    );
    return (data ?? [])
        .whereType<Map>()
        .map((item) => PostContentMeta.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// 获取文章正文。
  Future<PostContent> postPublishContent(int postId) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/post/publish/$postId',
      parse: _requireMap,
    );
    if (data == null) {
      throw StateError('正文数据缺失');
    }
    return PostContent.fromJson(data);
  }

  /// 获取文章草稿内容。
  Future<PostContent> postDraftContent(int postId, String draftName) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/post/$postId/draft/$draftName',
      parse: _requireMap,
    );
    if (data == null) {
      throw StateError('草稿数据缺失');
    }
    return PostContent.fromJson(data);
  }

  /// 修改文章正文。
  Future<bool> updatePublish(int postId, String content) async {
    return await _client.put<bool>(
          '/admin/post/publish',
          body: {'postId': postId, 'content': content},
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 添加文章草稿。
  Future<bool> addDraft({
    required int postId,
    required String content,
    required String draftName,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/post/draft',
      body: {
        'postId': postId,
        'content': content,
        'draftName': draftName,
      },
      parse: _optionalMap,
    );
    return data != null;
  }

  /// 修改文章草稿。
  Future<bool> updateDraft({
    required int postId,
    required String content,
    required String draftName,
  }) async {
    return await _client.put<bool>(
          '/admin/post/draft',
          body: {
            'postId': postId,
            'content': content,
            'draftName': draftName,
          },
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除文章草稿。
  Future<bool> deleteDrafts(int postId, List<String> draftNames) async {
    return await _client.delete<bool>(
          '/admin/post/draft/$postId',
          body: draftNames,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 修改文章草稿名。
  Future<bool> updateDraftName({
    required int postId,
    required String oldName,
    required String newName,
  }) async {
    return await _client.put<bool>(
          '/admin/post/draft/name',
          body: {
            'postId': postId,
            'oldName': oldName,
            'newName': newName,
          },
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 将文章草稿转换为文章正文。
  Future<bool> draft2Content({
    required int postId,
    required String draftName,
    required bool deleteContent,
    String? contentName,
  }) async {
    return await _client.put<bool>(
          '/admin/post/draft/publish',
          body: {
            'postId': postId,
            'draftName': draftName,
            'deleteContent': deleteContent,
            'contentName': contentName,
          },
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

Map<String, dynamic>? _optionalMap(Object? data) =>
    data == null ? null : Map<String, dynamic>.from(data as Map);

Map<String, dynamic> _requireMap(Object? data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('接口返回数据格式错误');
}

/// [PostApi] 提供者。
final postApiProvider = Provider<PostApi>((ref) {
  return PostApi(ref.watch(apiClientProvider));
});
