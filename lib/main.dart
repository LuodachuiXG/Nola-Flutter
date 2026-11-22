import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/window/title_bar.dart' as window;
import 'core/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web 端调试辅助：带 ?a11y 参数时启用语义树，
  // 便于自动化测试读取与操作语义节点。
  if (kIsWeb && Uri.base.queryParameters.containsKey('a11y')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // 桌面端（Windows / Linux）隐藏系统标题栏，使用自绘标题栏。
  await window.initDesktopWindow();

  // 初始化本地存储，注入 Riverpod 容器
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(LocalStorage(prefs)),
      ],
      child: const NolaApp(),
    ),
  );
}
