import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/file_models.dart';
import '../../../core/network/api_client.dart';

/// 附件（文件）API。
class FileApi {
  FileApi(this._client);

  final ApiClient _client;

  /// 上传文件。
  Future<FileItem?> upload({
    required String fileName,
    required List<int> fileBytes,
    int? fileGroupId,
    FileStorageMode? storageMode,
  }) async {
    final data = await _client.upload<Map<String, dynamic>>(
      '/admin/file',
      fileName: fileName,
      fileBytes: fileBytes,
      fields: {
        'fileGroupId': ?fileGroupId?.toString(),
        'storageMode': ?storageMode?.json,
      },
      parse: _optionalMap,
    );
    return data == null ? null : FileItem.fromJson(data);
  }

  /// 添加文件记录（登记外部文件，不上传内容）。
  Future<FileItem?> addRecord(FileRecordRequest request) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/file/record',
      body: request.toJson(),
      parse: _optionalMap,
    );
    return data == null ? null : FileItem.fromJson(data);
  }

  /// 分页获取文件。
  Future<Pager<FileItem>> files({
    required int page,
    required int size,
    FileSort? sort,
    FileStorageMode? mode,
    int? groupId,
    String? key,
  }) async {
    return await _client.get<Pager<FileItem>>(
      '/admin/file',
      query: {
        'page': page,
        'size': size,
        'sort': ?sort?.json,
        'mode': ?mode?.json,
        'groupId': ?groupId,
        if (key != null && key.isNotEmpty) 'key': key,
      },
      parse: (data) => Pager.fromJson(
        Map<String, dynamic>.from(data as Map),
        FileItem.fromJson,
      ),
    ) as Pager<FileItem>;
  }

  /// 根据文件 ID 集合删除文件。
  Future<bool> deleteFiles(List<int> ids) async {
    return await _client.delete<bool>(
          '/admin/file',
          body: ids,
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 根据文件索引（名称 + 存储方式）删除文件。
  Future<bool> deleteFilesByIndexes(List<FileIndex> indexes) async {
    return await _client.delete<bool>(
          '/admin/file/name',
          body: indexes.map((e) => e.toJson()).toList(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 移动文件到新文件组。
  Future<bool> moveFiles(List<int> fileIds, int? newFileGroupId) async {
    return await _client.put<bool>(
          '/admin/file',
          body: FileMoveRequest(
            fileIds: fileIds,
            newFileGroupId: newFileGroupId,
          ).toJson(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 获取文件组（可按存储方式过滤）。
  Future<List<FileGroup>> groups({FileStorageMode? storageMode}) async {
    final data = await _client.get<List<dynamic>>(
      '/admin/file/group',
      query: {
        if (storageMode != null) 'fileStorageMode': storageMode.json,
      },
      parse: (data) => data as List<dynamic>? ?? [],
    );
    return (data ?? [])
        .whereType<Map>()
        .map((item) => FileGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// 添加文件组。
  Future<FileGroup?> addGroup({
    required String displayName,
    required String path,
    required FileStorageMode storageMode,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/file/group',
      body: FileGroup.addJson(
        displayName: displayName,
        path: path,
        storageMode: storageMode,
      ),
      parse: _optionalMap,
    );
    return data == null ? null : FileGroup.fromJson(data);
  }

  /// 修改文件组名称。
  Future<bool> updateGroup({
    required int fileGroupId,
    required String displayName,
  }) async {
    return await _client.put<bool>(
          '/admin/file/group',
          body: FileGroup.updateJson(
            fileGroupId: fileGroupId,
            displayName: displayName,
          ),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除文件组。
  Future<bool> deleteGroup(int fileGroupId) async {
    return await _client.delete<bool>(
          '/admin/file/group/$fileGroupId',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 获取已配置的存储方式（始终包含本地存储）。
  Future<List<FileStorageMode>> modes() async {
    final data = await _client.get<List<dynamic>>(
      '/admin/file/mode',
      parse: (data) => data as List<dynamic>? ?? [],
    );
    return (data ?? [])
        .whereType<String>()
        .map(
          (name) => parseEnumOrNull(FileStorageMode.values, name) ??
              FileStorageMode.local,
        )
        .toList();
  }

  /// 获取腾讯云 COS 配置。
  Future<TencentCOSConfig?> tencentCOS() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/file/mode/tencent_cos',
      parse: _optionalMap,
    );
    return data == null ? null : TencentCOSConfig.fromJson(data);
  }

  /// 设置腾讯云 COS 配置。
  Future<bool> setTencentCOS(TencentCOSConfig config) async {
    return await _client.post<bool>(
          '/admin/file/mode/tencent_cos',
          body: config.toJson(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 删除腾讯云 COS 配置。
  Future<bool> deleteTencentCOS() async {
    return await _client.delete<bool>(
          '/admin/file/mode/tencent_cos',
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

Map<String, dynamic>? _optionalMap(Object? data) =>
    data == null ? null : Map<String, dynamic>.from(data as Map);

/// [FileApi] 提供者。
final fileApiProvider = Provider<FileApi>((ref) {
  return FileApi(ref.watch(apiClientProvider));
});
