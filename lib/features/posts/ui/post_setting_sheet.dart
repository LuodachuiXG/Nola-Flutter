import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/post.dart';
import '../../../core/models/taxonomy.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/attachment_picker.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../files/data/file_api.dart';
import '../data/post_api.dart';
import '../providers/post_providers.dart';

/// 展示文章设置底部弹层。
///
/// [post] 为 null 时为新建模式；[onSaved] 在保存成功后回调。
Future<void> showPostSettingSheet(
  BuildContext context, {
  Post? post,
  ValueChanged<Post>? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _PostSettingSheet(post: post, onSaved: onSaved),
    ),
  );
}

class _PostSettingSheet extends ConsumerStatefulWidget {
  const _PostSettingSheet({this.post, this.onSaved});

  final Post? post;
  final ValueChanged<Post>? onSaved;

  @override
  ConsumerState<_PostSettingSheet> createState() => _PostSettingSheetState();
}

class _PostSettingSheetState extends ConsumerState<_PostSettingSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _slugController;
  late final TextEditingController _excerptController;
  late final TextEditingController _coverController;
  late final TextEditingController _passwordController;

  late bool _autoGenerateExcerpt;
  late bool _allowComment;
  late bool _pinned;
  late PostStatus _status;
  late PostVisible _visible;
  late bool _encrypted;
  int? _categoryId;
  List<int> _tagIds = [];

  bool _saving = false;
  bool _uploadingCover = false;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _titleController = TextEditingController(text: post?.title ?? '');
    _slugController = TextEditingController(text: post?.slug ?? '');
    _excerptController = TextEditingController(text: post?.excerpt ?? '');
    _coverController = TextEditingController(text: post?.cover ?? '');
    _passwordController = TextEditingController();
    _autoGenerateExcerpt = post?.autoGenerateExcerpt ?? true;
    _allowComment = post?.allowComment ?? true;
    _pinned = post?.pinned ?? false;
    _status = post?.status ?? PostStatus.published;
    _visible = post?.visible ?? PostVisible.visible;
    _encrypted = post?.encrypted ?? false;
    _categoryId = post?.category?.categoryId;
    _tagIds = post?.tags.map((t) => t.tagId).toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _excerptController.dispose();
    _coverController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 上传封面。
  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    // 空列表时 files.single 会抛 StateError，安全取第一个
    final file = (result == null || result.files.isEmpty)
        ? null
        : result.files.first;
    if (file == null || file.bytes == null) return;
    setState(() => _uploadingCover = true);
    try {
      final item = await ref.read(fileApiProvider).upload(
            fileName: file.name,
            fileBytes: file.bytes!,
          );
      if (item == null) {
        if (mounted) showGlobalSnack( '封面上传失败', error: true);
        return;
      }
      setState(() => _coverController.text = item.url);
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  /// 提交保存。
  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showGlobalSnack( '请输入文章标题', error: true);
      return;
    }
    if (_status == PostStatus.deleted) {
      showGlobalSnack( '文章状态不能设置为回收站', error: true);
      return;
    }

    // 别名留空时使用标题
    var slug = _slugController.text.trim();
    if (slug.isEmpty) slug = title;

    // 组装加密与密码参数
    // true + 密码：设置新密码；null：编辑时保持不变；false：清除密码
    bool? encryptedFlag;
    String? password;
    if (_isEdit) {
      final wasEncrypted = widget.post!.encrypted;
      if (_encrypted && _passwordController.text.isNotEmpty) {
        encryptedFlag = true;
        password = _passwordController.text;
      } else if (_encrypted && wasEncrypted) {
        // 保持原密码不变
        encryptedFlag = null;
      } else if (_encrypted && !wasEncrypted) {
        showGlobalSnack( '文章设为加密需要提供密码', error: true);
        return;
      } else {
        encryptedFlag = false;
      }
    } else {
      if (_encrypted && _passwordController.text.isEmpty) {
        showGlobalSnack( '文章设为加密需要提供密码', error: true);
        return;
      }
      encryptedFlag = _encrypted;
      password =
          _passwordController.text.isEmpty ? null : _passwordController.text;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(postApiProvider);
      final request = PostRequest(
        postId: _isEdit ? widget.post!.postId : null,
        title: title,
        autoGenerateExcerpt: _autoGenerateExcerpt,
        excerpt: _excerptController.text.trim().isEmpty
            ? null
            : _excerptController.text.trim(),
        slug: slug,
        allowComment: _allowComment,
        status: _status,
        visible: _visible,
        // 编辑时不修改正文内容
        content: null,
        categoryId: _categoryId,
        tagIds: _tagIds,
        cover: _coverController.text.trim().isEmpty
            ? null
            : _coverController.text.trim(),
        pinned: _pinned,
        encrypted: encryptedFlag,
        password: password,
      );

      if (_isEdit) {
        final ok = await api.updatePost(request);
        if (!ok) {
          if (mounted) showGlobalSnack( '修改文章失败', error: true);
          return;
        }
        if (mounted) {
          showGlobalSnack( '文章已保存');
          Navigator.of(context).pop();
          widget.onSaved?.call(widget.post!);
        }
      } else {
        final created = await api.addPost(request);
        if (created == null) {
          if (mounted) showGlobalSnack( '创建文章失败', error: true);
          return;
        }
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSaved?.call(created);
        }
      }
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(allCategoriesProvider);
    final tags = ref.watch(allTagsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _isEdit ? '文章设置' : '新建文章',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _slugController,
                      decoration: const InputDecoration(
                        labelText: '别名（URL，留空使用标题）',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _excerptController,
                      decoration: const InputDecoration(
                        labelText: '摘要',
                      ),
                      maxLines: 3,
                      enabled: !_autoGenerateExcerpt,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自动生成摘要'),
                      value: _autoGenerateExcerpt,
                      onChanged: (value) =>
                          setState(() => _autoGenerateExcerpt = value),
                    ),
                    const SizedBox(height: 8),
                    // 封面
                    Text('封面', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coverController,
                            decoration: const InputDecoration(
                              hintText: '封面图片地址',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () async {
                            final item = await showAttachmentPicker(
                              context,
                              imageOnly: true,
                            );
                            if (item == null) return;
                            _coverController.text = item.url;
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          tooltip: '从附件库选择',
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: _uploadingCover ? null : _pickCover,
                          icon: _uploadingCover
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_rounded),
                          tooltip: '上传封面',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 分类
                    categories.when(
                      data: (data) => DropdownButtonFormField<int>(
                        // 文章原分类可能已被删除，失效时回退为「无分类」
                        initialValue:
                            data.any((c) => c.categoryId == _categoryId)
                                ? _categoryId
                                : null,
                        decoration: const InputDecoration(
                          labelText: '分类',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('无分类'),
                          ),
                          for (final category in data)
                            DropdownMenuItem(
                              value: category.categoryId,
                              child: Text(category.displayName),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text('分类加载失败：$error'),
                    ),
                    const SizedBox(height: 12),
                    // 标签
                    tags.when(
                      data: (data) => _TagSelector(
                        tags: data,
                        selectedIds: _tagIds,
                        onChanged: (ids) => setState(() => _tagIds = ids),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text('标签加载失败：$error'),
                    ),
                    const SizedBox(height: 8),
                    // 状态与可见性
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<PostStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: '状态',
                            ),
                            items: [
                              for (final value in [
                                PostStatus.published,
                                PostStatus.draft
                              ])
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _status = value ?? _status),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<PostVisible>(
                            initialValue: _visible,
                            decoration: const InputDecoration(
                              labelText: '可见性',
                            ),
                            items: [
                              for (final value in PostVisible.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _visible = value ?? _visible),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('允许评论'),
                      value: _allowComment,
                      onChanged: (value) =>
                          setState(() => _allowComment = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('置顶'),
                      value: _pinned,
                      onChanged: (value) => setState(() => _pinned = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('访问加密'),
                      subtitle: _isEdit
                          ? const Text('关闭将清除已设置的密码')
                          : null,
                      value: _encrypted,
                      onChanged: (value) =>
                          setState(() => _encrypted = value),
                    ),
                    if (_encrypted == true)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText:
                              _isEdit ? '访问密码（留空保持不变）' : '访问密码',
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? '保存设置' : '创建文章'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签多选器。
class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<Tag> tags;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tags.isEmpty) {
      return Text(
        '标签：暂无',
        style: theme.textTheme.bodySmall,
      );
    }
    // 标签较多时限高内部滚动，避免把整个弹层撑得拥挤。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('标签（已选 ${selectedIds.length}）', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  FilterChip(
                    label: Text(tag.displayName),
                    selected: selectedIds.contains(tag.tagId),
                    onSelected: (selected) {
                      final ids = [...selectedIds];
                      if (selected) {
                        ids.add(tag.tagId);
                      } else {
                        ids.remove(tag.tagId);
                      }
                      onChanged(ids);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
