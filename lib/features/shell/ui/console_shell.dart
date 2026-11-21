import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 控制台导航目的地。
class ConsoleDestination {
  const ConsoleDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 全部导航目的地（顺序与侧栏展示一致）。
const List<ConsoleDestination> kConsoleDestinations = [
  ConsoleDestination(
    path: '/dashboard',
    label: '概览',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  ConsoleDestination(
    path: '/posts',
    label: '文章',
    icon: Icons.article_outlined,
    selectedIcon: Icons.article_rounded,
  ),
  ConsoleDestination(
    path: '/categories',
    label: '分类',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
  ),
  ConsoleDestination(
    path: '/tags',
    label: '标签',
    icon: Icons.sell_outlined,
    selectedIcon: Icons.sell_rounded,
  ),
  ConsoleDestination(
    path: '/comments',
    label: '评论',
    icon: Icons.mode_comment_outlined,
    selectedIcon: Icons.mode_comment_rounded,
  ),
  ConsoleDestination(
    path: '/diaries',
    label: '日常',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note_rounded,
  ),
  ConsoleDestination(
    path: '/files',
    label: '附件',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
  ),
  ConsoleDestination(
    path: '/links',
    label: '友链',
    icon: Icons.link_outlined,
    selectedIcon: Icons.link_rounded,
  ),
  ConsoleDestination(
    path: '/menus',
    label: '菜单',
    icon: Icons.menu_open_outlined,
    selectedIcon: Icons.menu_open_rounded,
  ),
  ConsoleDestination(
    path: '/backup',
    label: '备份',
    icon: Icons.backup_outlined,
    selectedIcon: Icons.backup_rounded,
  ),
  ConsoleDestination(
    path: '/system',
    label: '系统',
    icon: Icons.terminal_outlined,
    selectedIcon: Icons.terminal_rounded,
  ),
  ConsoleDestination(
    path: '/settings',
    label: '设置',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

/// 根据当前路由位置计算选中的导航索引。
int consoleDestinationIndex(String location) {
  for (var i = 0; i < kConsoleDestinations.length; i++) {
    if (location == kConsoleDestinations[i].path ||
        location.startsWith('${kConsoleDestinations[i].path}/')) {
      return i;
    }
  }
  return 0;
}

/// Shell 作用域：向子页面暴露 Shell 的 Scaffold Key，
/// 用于页面内 AppBar 打开外层抽屉（页面自带 Scaffold，
/// 直接 Scaffold.of 只能找到内层）。
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.scaffoldKey,
    required super.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}

/// 控制台 Shell：窄屏使用抽屉导航，宽屏使用侧边导航栏。
class ConsoleShell extends StatefulWidget {
  const ConsoleShell({super.key, required this.child});

  final Widget child;

  /// 是否为宽屏布局。
  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  State<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends State<ConsoleShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = consoleDestinationIndex(location);
    final child = ShellScope(
      scaffoldKey: _scaffoldKey,
      child: widget.child,
    );

    if (ConsoleShell.isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _buildRail(context, selectedIndex),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, selectedIndex),
      body: child,
    );
  }

  /// 宽屏侧边导航栏。
  Widget _buildRail(BuildContext context, int selectedIndex) {
    final extended = MediaQuery.of(context).size.width >= 1300;
    return NavigationRail(
      selectedIndex: selectedIndex,
      extended: extended,
      minExtendedWidth: 180,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Image.asset(
          'assets/nola_logo.png',
          width: 32,
          height: 32,
        ),
      ),
      destinations: [
        for (final destination in kConsoleDestinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
      onDestinationSelected: (index) =>
          context.go(kConsoleDestinations[index].path),
    );
  }

  /// 窄屏抽屉导航。
  Widget _buildDrawer(BuildContext context, int selectedIndex) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(kConsoleDestinations[index].path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Image.asset(
                'assets/nola_logo.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Nola 控制台',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final destination in kConsoleDestinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// 控制台页面通用 AppBar。
///
/// 窄屏时自动展示抽屉按钮；宽屏时仅展示标题。
class ConsoleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ConsoleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final wide = ConsoleShell.isWide(context);
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: false,
      leading: wide
          ? null
          : IconButton(
              icon: const Icon(Icons.menu),
              tooltip: '打开菜单',
              onPressed: () => ShellScope.maybeOf(context)
                  ?.scaffoldKey
                  .currentState
                  ?.openDrawer(),
            ),
      actions: actions,
      bottom: bottom,
    );
  }
}
