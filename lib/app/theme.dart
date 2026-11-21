/// 应用主题配置（Material 3）。
library;

import 'package:flutter/material.dart';

/// Nola 品牌主色（与官方 Logo / Vue 控制台一致）。
const Color kDefaultSeedColor = Color(0xFF306FFF);

/// 主题色预设色板（第一个为品牌默认色）。
const List<Color> kPresetSeedColors = [
  kDefaultSeedColor,
  Color(0xFF3FB27F),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFF64748B),
];

/// 构建应用主题。
///
/// [seedColor] 为用户选择的主题色，亮暗两套配色共用同一种子色。
ThemeData buildAppTheme(Brightness brightness, Color seedColor) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: const CardThemeData(elevation: 0),
  );
}
