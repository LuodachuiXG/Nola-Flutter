import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/system_models.dart';
import '../../../core/network/api_client.dart';

/// 备份 API。
class BackupApi {
  BackupApi(this._client);

  final ApiClient _client;

  /// 导入 Markdown / Txt 文件为新文章。
  Future<ImportPostResult> importPosts(
    Map<String, List<int>> files,
  ) async {
    final data = await _client.uploadFiles<Map<String, dynamic>>(
      '/admin/backup/post',
      files: files,
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    if (data == null) {
      throw StateError('导入响应数据缺失');
    }
    return ImportPostResult.fromJson(data);
  }

  /// 导出全部文章为 Markdown 压缩包。
  Future<ExportPostResult> exportPosts() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/backup/post',
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    if (data == null) {
      throw StateError('导出响应数据缺失');
    }
    return ExportPostResult.fromJson(data);
  }

  /// 下载导出的备份压缩包。
  ///
  /// [fileName] 为导出接口返回的 `path` 字段（zip 文件名）。
  Future<String> downloadExport(String fileName, String savePath) async {
    return _client.download('/admin/backup/download/$fileName', savePath);
  }

  /// 上传备份 zip 预览恢复操作（不修改数据）。
  Future<RestorePreview> previewRestore({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final data = await _client.upload<Map<String, dynamic>>(
      '/admin/backup/restore/preview',
      fileName: fileName,
      fileBytes: fileBytes,
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    if (data == null) {
      throw StateError('预览响应数据缺失');
    }
    return RestorePreview.fromJson(data);
  }

  /// 执行备份恢复。
  Future<RestoreResult> applyRestore({
    required String token,
    String? conflictStrategy,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/backup/restore/apply',
      body: {'token': token, 'conflictStrategy': conflictStrategy},
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    if (data == null) {
      throw StateError('恢复响应数据缺失');
    }
    return RestoreResult.fromJson(data);
  }
}

/// [BackupApi] 提供者。
final backupApiProvider = Provider<BackupApi>((ref) {
  return BackupApi(ref.watch(apiClientProvider));
});
