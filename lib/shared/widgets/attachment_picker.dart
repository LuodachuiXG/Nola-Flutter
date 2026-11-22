import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/file_models.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/formatters.dart';
import '../../features/files/data/file_api.dart';

/// 打开「从附件库选择」对话框。
///
/// [imageOnly] 为 true 时仅展示图片类型附件（用于封面、Logo 等场景）。
/// 返回选中的 [FileItem]；用户取消时返回 null。
Future<FileItem?> showAttachmentPicker(
  BuildContext context, {
  bool imageOnly = false,
}) {
  return showDialog<FileItem>(
    context: context,
    builder: (context) => _AttachmentPickerDialog(imageOnly: imageOnly),
  );
}

/// 按扩展名判断是否为图片文件。
bool _isImageFile(String name) {
  const extensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
  final index = name.lastIndexOf('.');
  if (index < 0) return false;
  return extensions.contains(name.substring(index + 1).toLowerCase());
}

class _AttachmentPickerDialog extends ConsumerStatefulWidget {
  const _AttachmentPickerDialog({this.imageOnly = false});

  final bool imageOnly;

  @override
  ConsumerState<_AttachmentPickerDialog> createState() =>
      _AttachmentPickerDialogState();
}

class _AttachmentPickerDialogState
    extends ConsumerState<_AttachmentPickerDialog> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<FileItem> _items = [];
  String _keyword = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动接近底部时加载下一页。
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pager = await ref.read(fileApiProvider).files(
            page: _page + 1,
            size: _pageSize,
            key: _keyword.isEmpty ? null : _keyword,
          );
      if (!mounted) return;
      setState(() {
        _page = pager.page;
        _hasMore = pager.hasMore;
        _items.addAll(pager.data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '附件加载失败：$error';
      });
    }
  }

  Future<void> _search(String keyword) async {
    setState(() {
      _keyword = keyword.trim();
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  /// imageOnly 模式下按扩展名过滤出图片。
  List<FileItem> get _visibleItems => widget.imageOnly
      ? _items.where((f) => _isImageFile(f.displayName)).toList()
      : _items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _visibleItems;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.imageOnly ? '选择图片' : '选择附件',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索文件名',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        ),
                ),
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(theme, items)),
              const SizedBox(height: 8),
              Text(
                _footerText(items.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _footerText(int count) {
    final scope = widget.imageOnly ? '图片' : '附件';
    if (_loading) return '加载中…';
    if (_error != null) return _error!;
    return '共 $count 个$scope';
  }

  Widget _buildBody(ThemeData theme, List<FileItem> items) {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadMore, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          _keyword.isEmpty ? '暂无${widget.imageOnly ? '图片' : '附件'}' : '没有匹配的附件',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 末尾为加载更多指示
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return _AttachmentGridItem(item: items[index]);
      },
    );
  }
}

/// 附件网格项：图片显示缩略图，其它文件显示图标，点击即选中返回。
class _AttachmentGridItem extends ConsumerWidget {
  const _AttachmentGridItem({required this.item});

  final FileItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serverUrl = ref.read(localStorageProvider).serverUrl;
    final isImage = _isImageFile(item.displayName);
    final url = resolveFileUrl(item.url, serverUrl);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(item),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isImage
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          size: 36,
                          color: theme.colorScheme.outline,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          Text(
            formatFileSize(item.size),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
