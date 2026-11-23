import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/auth/ui/biometric_enrollment_prompt.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/shell/ui/console_shell.dart';
import '../features/dashboard/ui/dashboard_screen.dart';
import '../features/posts/ui/post_list_screen.dart';
import '../features/posts/ui/post_edit_screen.dart';
import '../features/taxonomy/ui/category_screen.dart';
import '../features/taxonomy/ui/tag_screen.dart';
import '../features/comments/ui/comment_screen.dart';
import '../features/diaries/ui/diary_screen.dart';
import '../features/files/ui/file_screen.dart';
import '../features/links/ui/link_screen.dart';
import '../features/menus/ui/menu_screen.dart';
import '../features/backup/ui/backup_screen.dart';
import '../features/system/ui/system_screen.dart';
import '../features/settings/ui/settings_screen.dart';

/// 根导航器 Key，用于无上下文弹提示。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 应用路由配置。
///
/// 未登录时所有控制台路由重定向到登录页；已登录访问登录页时
/// 重定向到概览页。
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggedIn = session != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => BiometricEnrollmentPrompt(
          child: ConsoleShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/posts',
            builder: (context, state) => const PostListScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoryScreen(),
          ),
          GoRoute(
            path: '/tags',
            builder: (context, state) => const TagScreen(),
          ),
          GoRoute(
            path: '/comments',
            builder: (context, state) => const CommentScreen(),
          ),
          GoRoute(
            path: '/diaries',
            builder: (context, state) => const DiaryScreen(),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const FileScreen(),
          ),
          GoRoute(
            path: '/links',
            builder: (context, state) => const LinkScreen(),
          ),
          GoRoute(
            path: '/menus',
            builder: (context, state) => const MenuScreen(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/system',
            builder: (context, state) => const SystemScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      // 文章编辑器为全屏页面（不带控制台导航）
      GoRoute(
        path: '/post-editor',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final postId = int.tryParse(
            state.uri.queryParameters['postId'] ?? '',
          );
          return PostEditScreen(postId: postId);
        },
      ),
    ],
  );

  // 会话变化会重建路由，释放旧实例的监听与资源
  ref.onDispose(router.dispose);
  return router;
});
