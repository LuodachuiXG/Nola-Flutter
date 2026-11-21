import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/storage/local_storage.dart';

/// 应用主题模式。
enum AppThemeMode {
  system('system', '跟随系统'),
  light('light', '亮色'),
  dark('dark', '暗色');

  const AppThemeMode(this.json, this.label);

  /// 持久化名称。
  final String json;

  /// 展示名称。
  final String label;
}

/// 应用外观设置。
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.seedColor,
    this.useCustomSeed = false,
  });

  /// 主题模式。
  final AppThemeMode themeMode;

  /// 主题色。
  final Color seedColor;

  /// 是否使用自定义主题色（false 时为品牌默认色）。
  final bool useCustomSeed;

  /// 对应的 Material ThemeMode。
  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

/// 应用设置状态管理：主题模式与主题色，均持久化到本地。
class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // 外观设置全局常驻
    ref.keepAlive();

    final storage = ref.watch(localStorageProvider);
    final themeMode = switch (storage.themeModeName) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
    final hex = storage.seedColorHex;
    final argb = hex == null ? null : int.tryParse('FF$hex', radix: 16);
    return AppSettings(
      themeMode: themeMode,
      seedColor: argb == null ? kDefaultSeedColor : Color(argb),
      useCustomSeed: argb != null,
    );
  }

  /// 切换主题模式。
  Future<void> setThemeMode(AppThemeMode mode) async {
    await ref.read(localStorageProvider).setThemeModeName(mode.json);
    state = AppSettings(
      themeMode: mode,
      seedColor: state.seedColor,
      useCustomSeed: state.useCustomSeed,
    );
  }

  /// 设置主题色，传 null 恢复品牌默认色。
  Future<void> setSeedColor(Color? color) async {
    final storage = ref.read(localStorageProvider);
    if (color == null) {
      await storage.setSeedColorHex(null);
      state = AppSettings(
        themeMode: state.themeMode,
        seedColor: kDefaultSeedColor,
        useCustomSeed: false,
      );
      return;
    }
    final hex =
        color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    await storage.setSeedColorHex(hex);
    state = AppSettings(
      themeMode: state.themeMode,
      seedColor: color,
      useCustomSeed: true,
    );
  }
}

/// 应用设置提供者。
final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);
