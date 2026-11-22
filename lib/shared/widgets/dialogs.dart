/// 通用对话框与提示工具。
library;

import 'package:flutter/material.dart';

/// 显示确认对话框。
///
/// 返回 true 表示用户确认，false 或 null 表示取消。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String confirmText = '确认',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      // 在对话框内取主题，避免主题切换时颜色不更新
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 显示自定义表单对话框。
///
/// [builder] 中构建表单内容，点击保存时调用 [onSave]，
/// 返回 true 表示校验通过并关闭对话框，返回 false 保持打开。
Future<void> showFormDialog(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  required Future<bool> Function() onSave,
  String saveText = '保存',
  bool barrierDismissible = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => _FormDialog(
      title: title,
      builder: builder,
      onSave: onSave,
      saveText: saveText,
    ),
  );
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.builder,
    required this.onSave,
    required this.saveText,
  });

  final String title;
  final WidgetBuilder builder;
  final Future<bool> Function() onSave;
  final String saveText;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  bool _saving = false;

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSave();
      if (ok && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(child: widget.builder(context)),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _handleSave,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saveText),
        ),
      ],
    );
  }
}

/// 显示底部弹层表单（移动端更友好的大表单入口）。
Future<void> showFormSheet(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  required Future<bool> Function() onSave,
  String saveText = '保存',
  bool isScrollControlled = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) => _FormSheet(
      title: title,
      builder: builder,
      onSave: onSave,
      saveText: saveText,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({
    required this.title,
    required this.builder,
    required this.onSave,
    required this.saveText,
  });

  final String title;
  final WidgetBuilder builder;
  final Future<bool> Function() onSave;
  final String saveText;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool _saving = false;

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSave();
      if (ok && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: widget.builder(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.saveText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全局 SnackBar Key，挂载于 MaterialApp，用于无上下文提示。
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 在任意位置显示提示 SnackBar（无需 BuildContext）。
///
/// [error] 为 true 时使用错误配色（与 [showSnack] 保持一致）。
void showGlobalSnack(
  String message, {
  bool error = false,
  IconData? icon,
}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final theme = Theme.of(messenger.context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: error ? theme.colorScheme.onError : null,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? theme.colorScheme.error : theme.colorScheme.inverseSurface,
      ),
    );
}

/// 显示提示 SnackBar。
void showSnack(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
}) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: error
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onInverseSurface,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? theme.colorScheme.error : theme.colorScheme.inverseSurface,
      ),
    );
}
