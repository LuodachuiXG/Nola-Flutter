/// 通用数据模型：分页与文件索引。
library;

import 'enums.dart';

/// 分页数据结构，对应后端 `Pager<T>`。
class Pager<T> {
  const Pager({
    required this.page,
    required this.size,
    required this.data,
    required this.totalData,
    required this.totalPages,
  });

  /// 当前页（0 表示全部）。
  final int page;

  /// 每页条数（0 表示全部）。
  final int size;

  /// 当前页数据。
  final List<T> data;

  /// 总条数。
  final int totalData;

  /// 总页数。
  final int totalPages;

  /// 是否还有下一页。
  bool get hasMore => page < totalPages;

  factory Pager.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromJsonItem,
  ) {
    return Pager<T>(
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => fromJsonItem(Map<String, dynamic>.from(item)))
          .toList(),
      totalData: (json['totalData'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 文件索引，用于按名称精确删除不同存储方式下的文件。
class FileIndex {
  const FileIndex({this.fileId, required this.name, required this.storageMode});

  /// 文件 ID。
  final int? fileId;

  /// 文件名（含分组路径，如 `/img/1.jpg`）。
  final String name;

  /// 文件存储方式。
  final FileStorageMode storageMode;

  factory FileIndex.fromJson(Map<String, dynamic> json) => FileIndex(
        fileId: (json['fileId'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        storageMode: parseEnum(
          FileStorageMode.values,
          json['storageMode'] as String?,
          FileStorageMode.local,
        ),
      );

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'name': name,
        'storageMode': storageMode.json,
      };
}
