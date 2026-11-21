/// 附件（文件）相关模型。
library;

import 'enums.dart';

/// 文件，对应后端 `FileResponse`。
class FileItem {
  const FileItem({
    required this.fileId,
    this.fileGroupId,
    this.fileGroupName,
    required this.displayName,
    required this.url,
    required this.size,
    required this.storageMode,
    required this.createTime,
  });

  final int fileId;
  final int? fileGroupId;
  final String? fileGroupName;
  final String displayName;

  /// 文件访问地址：本地存储为相对路径（如 `/upload/img/1.jpg`），
  /// 需要拼接服务器地址；对象存储为完整 URL。
  final String url;
  final int size;
  final FileStorageMode storageMode;
  final int createTime;

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        fileId: (json['fileId'] as num?)?.toInt() ?? -1,
        fileGroupId: (json['fileGroupId'] as num?)?.toInt(),
        fileGroupName: json['fileGroupName'] as String?,
        displayName: json['displayName'] as String? ?? '',
        url: json['url'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        storageMode: parseEnum(
          FileStorageMode.values,
          json['storageMode'] as String?,
          FileStorageMode.local,
        ),
        createTime: (json['createTime'] as num?)?.toInt() ?? 0,
      );
}

/// 文件组，对应后端 `FileGroup`。
class FileGroup {
  const FileGroup({
    required this.fileGroupId,
    required this.displayName,
    required this.path,
    required this.storageMode,
  });

  final int fileGroupId;
  final String displayName;
  final String path;
  final FileStorageMode storageMode;

  factory FileGroup.fromJson(Map<String, dynamic> json) => FileGroup(
        fileGroupId: (json['fileGroupId'] as num?)?.toInt() ?? -1,
        displayName: json['displayName'] as String? ?? '',
        path: json['path'] as String? ?? '',
        storageMode: parseEnum(
          FileStorageMode.values,
          json['storageMode'] as String?,
          FileStorageMode.local,
        ),
      );

  /// 新增文件组请求体（与后端 `FileGroup` 结构一致）。
  static Map<String, dynamic> addJson({
    required String displayName,
    required String path,
    required FileStorageMode storageMode,
  }) =>
      {
        'displayName': displayName,
        'path': path,
        'storageMode': storageMode.json,
      };

  /// 修改文件组请求体，对应后端 `FileGroupUpdateRequest`。
  static Map<String, dynamic> updateJson({
    required int fileGroupId,
    required String displayName,
  }) =>
      {
        'fileGroupId': fileGroupId,
        'displayName': displayName,
      };
}

/// 腾讯云对象存储配置，对应后端 `TencentCOSConfig`。
class TencentCOSConfig {
  const TencentCOSConfig({
    required this.secretId,
    required this.secretKey,
    required this.region,
    required this.bucket,
    this.path,
    required this.https,
  });

  final String secretId;
  final String secretKey;
  final String region;
  final String bucket;
  final String? path;
  final bool https;

  factory TencentCOSConfig.fromJson(Map<String, dynamic> json) =>
      TencentCOSConfig(
        secretId: json['secretId'] as String? ?? '',
        secretKey: json['secretKey'] as String? ?? '',
        region: json['region'] as String? ?? '',
        bucket: json['bucket'] as String? ?? '',
        path: json['path'] as String?,
        https: json['https'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'secretId': secretId,
        'secretKey': secretKey,
        'region': region,
        'bucket': bucket,
        'path': path,
        'https': https,
      };
}

/// 添加文件记录请求体，对应后端 `FileRecordRequest`。
class FileRecordRequest {
  const FileRecordRequest({
    required this.name,
    required this.size,
    this.storageMode,
    this.fileGroupId,
  });

  final String name;
  final int size;
  final FileStorageMode? storageMode;
  final int? fileGroupId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'storageMode': storageMode?.json,
        'fileGroupId': fileGroupId,
      };
}

/// 移动文件请求体，对应后端 `FileMoveRequest`。
class FileMoveRequest {
  const FileMoveRequest({
    required this.fileIds,
    this.newFileGroupId,
  });

  final List<int> fileIds;
  final int? newFileGroupId;

  Map<String, dynamic> toJson() => {
        'fileIds': fileIds,
        'newFileGroupId': newFileGroupId,
      };
}
