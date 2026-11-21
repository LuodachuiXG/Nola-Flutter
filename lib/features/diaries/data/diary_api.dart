import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/diary.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_client.dart';

/// 日记 API。
class DiaryApi {
  DiaryApi(this._client);

  final ApiClient _client;

  /// 分页获取日记。
  Future<Pager<Diary>> diaries({
    required int page,
    required int size,
    DiarySort? sort,
  }) async {
    return await _client.get<Pager<Diary>>(
      '/admin/diary',
      query: {
        'page': page,
        'size': size,
        if (sort != null) 'sort': sort.json,
      },
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        Diary.fromJson,
      ),
    ) as Pager<Diary>;
  }

  /// 添加日记。
  Future<Diary?> addDiary(String content) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/diary',
      body: Diary.requestJson(content: content),
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : Diary.fromJson(data);
  }

  /// 修改日记。
  Future<bool> updateDiary(int diaryId, String content) async {
    return await _client.put<bool>(
          '/admin/diary',
          body: Diary.requestJson(diaryId: diaryId, content: content),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除日记。
  Future<bool> deleteDiaries(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/diary',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [DiaryApi] 提供者。
final diaryApiProvider = Provider<DiaryApi>((ref) {
  return DiaryApi(ref.watch(apiClientProvider));
});
