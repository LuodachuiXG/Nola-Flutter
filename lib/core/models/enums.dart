/// Nola 后端所有业务枚举。
///
/// 每个枚举值的 [EnumWithJson.json] 与 Kotlin 后端枚举名保持一致，
/// 解析失败时统一返回各枚举指定的兜底值。
library;

/// 带后端枚举名的枚举标记接口。
abstract interface class EnumWithJson {
  /// 后端枚举名。
  String get json;
}

/// 文章状态。
enum PostStatus implements EnumWithJson {
  published('PUBLISHED', '已发布'),
  draft('DRAFT', '草稿'),
  deleted('DELETED', '回收站');

  const PostStatus(this.json, this.label);

  /// 后端枚举名。
  @override
  final String json;

  /// 展示名称。
  final String label;
}

/// 文章可见性。
enum PostVisible implements EnumWithJson {
  visible('VISIBLE', '可见'),
  hidden('HIDDEN', '隐藏');

  const PostVisible(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 文章排序。
enum PostSort implements EnumWithJson {
  createDesc('CREATE_DESC', '创建时间降序'),
  createAsc('CREATE_ASC', '创建时间升序'),
  modifyDesc('MODIFY_DESC', '修改时间降序'),
  modifyAsc('MODIFY_ASC', '修改时间升序'),
  visitDesc('VISIT_DESC', '访问量降序'),
  visitAsc('VISIT_ASC', '访问量升序'),
  pinned('PINNED', '置顶优先');

  const PostSort(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 文章内容状态。
enum PostContentStatus implements EnumWithJson {
  published('PUBLISHED', '正文'),
  draft('DRAFT', '草稿');

  const PostContentStatus(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 评论排序。
enum CommentSort implements EnumWithJson {
  createTimeDesc('CREATE_TIME_DESC', '时间降序'),
  createTimeAsc('CREATE_TIME_ASC', '时间升序');

  const CommentSort(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 日记排序。
enum DiarySort implements EnumWithJson {
  createTimeDesc('CREATE_TIME_DESC', '创建时间降序'),
  createTimeAsc('CREATE_TIME_ASC', '创建时间升序'),
  modifyTimeDesc('MODIFY_TIME_DESC', '修改时间降序'),
  modifyTimeAsc('MODIFY_TIME_ASC', '修改时间升序');

  const DiarySort(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 友情链接排序。
enum LinkSort implements EnumWithJson {
  priorityDesc('PRIORITY_DESC', '优先级降序'),
  priorityAsc('PRIORITY_ASC', '优先级升序'),
  createTimeDesc('CREATE_TIME_DESC', '创建时间降序'),
  createTimeAsc('CREATE_TIME_ASC', '创建时间升序'),
  modifyTimeDesc('MODIFY_TIME_DESC', '修改时间降序'),
  modifyTimeAsc('MODIFY_TIME_ASC', '修改时间升序');

  const LinkSort(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 文件排序。
enum FileSort implements EnumWithJson {
  createTimeDesc('CREATE_TIME_DESC', '时间降序'),
  createTimeAsc('CREATE_TIME_ASC', '时间升序'),
  sizeDesc('SIZE_DESC', '大小降序'),
  sizeAsc('SIZE_ASC', '大小升序');

  const FileSort(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 文件存储方式。
enum FileStorageMode implements EnumWithJson {
  local('LOCAL', '本地存储'),
  tencentCos('TENCENT_COS', '腾讯云 COS');

  const FileStorageMode(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 菜单项打开方式。
enum MenuItemTarget implements EnumWithJson {
  blank('BLANK', '新窗口'),
  self('SELF', '当前窗口'),
  parent('PARENT', '父窗口'),
  top('TOP', '顶级窗口');

  const MenuItemTarget(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 操作记录类型。
enum OperationType implements EnumWithJson {
  lowRisk('LOW_RISK', '普通操作'),
  highRisk('HIGH_RISK', '高风险操作');

  const OperationType(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 访问日志类型。
enum AccessLogType implements EnumWithJson {
  uri('URI', '路径访问'),
  blog('BLOG', '博客'),
  post('POST', '文章');

  const AccessLogType(this.json, this.label);

  @override
  final String json;

  final String label;
}

/// 读取枚举值的后端枚举名。
String _enumName(Object value) =>
    value is EnumWithJson ? value.json : (value as Enum).name;

/// 按后端枚举名解析枚举，失败时返回 [fallback]。
T parseEnum<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (_enumName(value) == name) return value;
  }
  return fallback;
}

/// 按后端枚举名解析枚举，失败或入参为空时返回 null。
T? parseEnumOrNull<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (_enumName(value) == name) return value;
  }
  return null;
}
