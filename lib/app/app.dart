import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/auth_events.dart';
import '../features/settings/providers/app_settings_providers.dart';
import '../shared/widgets/dialogs.dart';
import 'router.dart';
import 'theme.dart';
import 'window/title_bar.dart';

/// Nola 管理端应用根组件。
class NolaApp extends ConsumerStatefulWidget {
  const NolaApp({super.key});

  @override
  ConsumerState<NolaApp> createState() => _NolaAppState();
}

class _NolaAppState extends ConsumerState<NolaApp> {
  @override
  void initState() {
    super.initState();
    // 登录过期时给出全局提示（登出与跳转由会话控制器和路由完成）
    AuthEvents.stream.listen((_) {
      showGlobalSnack('登录已过期，请重新登录', error: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: 'Nola 控制台',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light, settings.seedColor),
      darkTheme: buildAppTheme(Brightness.dark, settings.seedColor),
      themeMode: settings.materialThemeMode,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: scaffoldMessengerKey,
      // 桌面端自绘标题栏挂在最外层：登录页、编辑页等所有路由页面均可见。
      builder: (context, child) => Column(
        children: [
          const WindowTitleBar(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
