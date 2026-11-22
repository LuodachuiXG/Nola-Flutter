import 'package:flutter/material.dart';

/// 非 IO 平台（Web 端）的空实现：没有桌面窗口概念。

/// 是否使用自绘标题栏（stub 恒为 false）。
const bool kCustomTitleBar = false;

/// 桌面窗口初始化（stub 空实现）。
Future<void> initDesktopWindow() async {}

/// 自绘标题栏占位组件（Web 端不渲染）。
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
