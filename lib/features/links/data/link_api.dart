import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_client.dart';

/// 友情链接 API。
class LinkApi {
  LinkApi(this._client);

  final ApiClient _client;

  /// 分页获取友情链接。
  Future<Pager<Link>> links({
    required int page,
    required int size,
    LinkSort? sort,
  }) async {
    return await _client.get<Pager<Link>>(
      '/admin/link',
      query: {
        'page': page,
        'size': size,
        if (sort != null) 'sort': sort.json,
      },
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Link.fromJson,
      ),
    ) as Pager<Link>;
  }

  /// 添加友情链接。
  Future<Link?> addLink(Map<String, dynamic> body) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/link',
      body: body,
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : Link.fromJson(data);
  }

  /// 修改友情链接。
  Future<bool> updateLink(Map<String, dynamic> body) async {
    return await _client.put<bool>(
          '/admin/link',
          body: body,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除友情链接。
  Future<bool> deleteLinks(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/link',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [LinkApi] 提供者。
final linkApiProvider = Provider<LinkApi>((ref) {
  return LinkApi(ref.watch(apiClientProvider));
});
