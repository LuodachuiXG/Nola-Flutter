/// 操作记录、访问日志与备份模型。
library;

import 'enums.dart';

/// 操作记录，对应后端 `Operation`。
class Operation {
  const Operation({
    required this.operationId,
    required this.username,
    required this.operationType,
    this.operationDesc,
    required this.createTime,
  });

  final int operationId;
  final String username;
  final OperationType operationType;
  final String? operationDesc;
  final int createTime;

  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
        operationId: (json['operationId'] as num?)?.toInt() ?? -1,
        username: json['username'] as String? ?? '',
        operationType: parseEnum(
          OperationType.values,
          json['operationType'] as String?,
          OperationType.lowRisk,
        ),
        operationDesc: json['operationDesc'] as String?,
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
      );
}

/// 访问日志，对应后端 `AccessLog`。
class AccessLog {
  const AccessLog({
    required this.accessLogId,
    required this.path,
    required this.ip,
    required this.accessTime,
    required this.type,
    this.message,
  });

  final int accessLogId;
  final String path;
  final String ip;
  final int accessTime;
  final AccessLogType type;
  final String? message;

  factory AccessLog.fromJson(Map<String, dynamic> json) => AccessLog(
        accessLogId: (json['accessLogId'] as num?)?.toInt() ?? -1,
        path: json['path'] as String? ?? '',
        ip: json['ip'] as String? ?? '',
        accessTime: (json['accessTime'] as num?)?.toInt() ?? 0,
        type: parseEnum(
          AccessLogType.values,
          json['type'] as String?,
          AccessLogType.uri,
        ),
        message: json['message'] as String?,
      );
}

/// 导出文章结果，对应后端 `ExportPostResponse`。
class ExportPostResult {
  const ExportPostResult({
    required this.path,
    required this.count,
    required this.successCount,
    required this.failCount,
    required this.failResult,
  });

  /// 导出的 zip 文件名。
  final String path;
  final int count;
  final int successCount;
  final int failCount;
  final List<String> failResult;

  factory ExportPostResult.fromJson(Map<String, dynamic> json) =>
      ExportPostResult(
        path: json['path'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        failCount: (json['failCount'] as num?)?.toInt() ?? 0,
        failResult: (json['failResult'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}

/// 备份恢复预览中的单个文件，对应后端 `RestorePreviewFile`。
class RestorePreviewFile {
  const RestorePreviewFile({
    required this.fileName,
    this.postId,
    this.slug,
    required this.type,
    required this.action,
    this.reason,
  });

  final String fileName;
  final int? postId;
  final String? slug;
  final String type;
  final String action;
  final String? reason;

  factory RestorePreviewFile.fromJson(Map<String, dynamic> json) =>
      RestorePreviewFile(
        fileName: json['fileName'] as String? ?? '',
        postId: (json['postId'] as num?)?.toInt(),
        slug: json['slug'] as String?,
        type: json['type'] as String? ?? '',
        action: json['action'] as String? ?? '',
        reason: json['reason'] as String?,
      );
}

/// 备份恢复预览，对应后端 `RestorePreviewResponse`。
class RestorePreview {
  const RestorePreview({
    required this.token,
    required this.expiresAt,
    required this.totalFiles,
    required this.publishedFiles,
    required this.draftFiles,
    required this.createPostCount,
    required this.updatePostCount,
    required this.addDraftCount,
    required this.conflictCount,
    required this.skipCount,
    required this.invalidCount,
    required this.files,
    required this.warnings,
  });

  final String token;
  final int expiresAt;
  final int totalFiles;
  final int publishedFiles;
  final int draftFiles;
  final int createPostCount;
  final int updatePostCount;
  final int addDraftCount;
  final int conflictCount;
  final int skipCount;
  final int invalidCount;
  final List<RestorePreviewFile> files;
  final List<String> warnings;

  factory RestorePreview.fromJson(Map<String, dynamic> json) => RestorePreview(
        token: json['token'] as String? ?? '',
        expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
        totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
        publishedFiles: (json['publishedFiles'] as num?)?.toInt() ?? 0,
        draftFiles: (json['draftFiles'] as num?)?.toInt() ?? 0,
        createPostCount: (json['createPostCount'] as num?)?.toInt() ?? 0,
        updatePostCount: (json['updatePostCount'] as num?)?.toInt() ?? 0,
        addDraftCount: (json['addDraftCount'] as num?)?.toInt() ?? 0,
        conflictCount: (json['conflictCount'] as num?)?.toInt() ?? 0,
        skipCount: (json['skipCount'] as num?)?.toInt() ?? 0,
        invalidCount: (json['invalidCount'] as num?)?.toInt() ?? 0,
        files: (json['files'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((f) => RestorePreviewFile.fromJson(Map<String, dynamic>.from(f)))
            .toList(),
        warnings: (json['warnings'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}

/// 备份恢复执行结果，对应后端 `RestoreResultResponse`。
class RestoreResult {
  const RestoreResult({
    required this.createdPosts,
    required this.updatedPosts,
    required this.addedDrafts,
    required this.skippedFiles,
    required this.failedFiles,
    required this.failures,
  });

  final int createdPosts;
  final int updatedPosts;
  final int addedDrafts;
  final int skippedFiles;
  final int failedFiles;
  final List<String> failures;

  factory RestoreResult.fromJson(Map<String, dynamic> json) => RestoreResult(
        createdPosts: (json['createdPosts'] as num?)?.toInt() ?? 0,
        updatedPosts: (json['updatedPosts'] as num?)?.toInt() ?? 0,
        addedDrafts: (json['addedDrafts'] as num?)?.toInt() ?? 0,
        skippedFiles: (json['skippedFiles'] as num?)?.toInt() ?? 0,
        failedFiles: (json['failedFiles'] as num?)?.toInt() ?? 0,
        failures: (json['failures'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}

/// 备份导入结果（后端为 Map 返回）。
class ImportPostResult {
  const ImportPostResult({
    required this.fileCount,
    required this.successCount,
    required this.failCount,
    required this.failResult,
  });

  final int fileCount;
  final int successCount;
  final int failCount;
  final List<String> failResult;

  factory ImportPostResult.fromJson(Map<String, dynamic> json) =>
      ImportPostResult(
        fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        failCount: (json['failCount'] as num?)?.toInt() ?? 0,
        failResult: (json['failResult'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );
}
