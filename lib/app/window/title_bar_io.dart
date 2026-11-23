import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 是否使用自绘标题栏：Windows / Linux / macOS 隐藏系统标题栏自绘，
/// macOS 保留左上角原生红绿灯按钮，Web / 移动端不适用。
final bool kCustomTitleBar =
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// 桌面窗口初始化：隐藏系统标题栏、设置默认尺寸并居中显示。
///
/// 仅在 [kCustomTitleBar] 平台生效，其它平台为空操作。
Future<void> initDesktopWindow() async {
  if (!kCustomTitleBar) return;
  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(520, 400),
    center: true,
    title: 'Nola 控制台',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: Platform.isMacOS,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// 自绘窗口标题栏：整栏可拖动移动窗口，双击最大化 / 还原。
/// Windows / Linux 在右侧绘制窗口控制按钮，macOS 使用左上角原生按钮。
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (!kCustomTitleBar) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _maximized = value);
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _maximized = false);
  }

  Future<void> _toggleMaximize() async {
    final maximized = await windowManager.isMaximized();
    if (maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kCustomTitleBar) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMacOS = Platform.isMacOS;
    return Material(
      // 沉浸式：与内容面板同色，无分割线。
      color: colorScheme.surface,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            // 拖拽区：Logo、标题与空白区域均可拖动窗口，双击最大化/还原。
            Expanded(
              child: DragToMoveArea(
                child: Row(
                  children: [
                    // 为 macOS 左上角的原生红绿灯按钮预留空间。
                    SizedBox(width: isMacOS ? 80 : 14),
                    Image.asset('assets/nola_logo.png', width: 16, height: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Nola 控制台',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 窗口按钮独立于拖拽区：避免双击手势识别器（~300ms 单击仲裁）造成按钮响应延迟。
            if (!isMacOS) ...[
              _WindowButton(
                icon: Icons.remove,
                onPressed: windowManager.minimize,
              ),
              _WindowButton(
                icon: _maximized ? Icons.filter_none : Icons.crop_square,
                onPressed: _toggleMaximize,
              ),
              _WindowButton(
                icon: Icons.close,
                onPressed: windowManager.close,
                isCloseButton: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 标题栏窗口控制按钮（Windows 风格：悬停高亮，关闭按钮悬停变红）。
///
/// 注意：标题栏位于 MaterialApp builder 层（Navigator 之外），
/// 没有 Overlay 祖先，不能使用 Tooltip 等依赖 Overlay 的组件。
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isCloseButton = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isCloseButton;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final closeHover = widget.isCloseButton && _hovering;
    final iconColor = closeHover ? Colors.white : colorScheme.onSurfaceVariant;
    final backgroundColor = widget.isCloseButton && _hovering
        ? const Color(0xFFE81123)
        : _hovering
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: widget.onPressed,
          child: SizedBox(
            width: 46,
            height: double.infinity,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
