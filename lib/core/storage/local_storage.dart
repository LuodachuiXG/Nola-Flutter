import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/server_url.dart';

/// 本地持久化存储，负责服务器地址、登录令牌与用户信息的读写。
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  /// 当前服务器地址。
  String get serverUrl =>
      _prefs.getString(StorageKeys.serverUrl) ?? kDefaultServerUrl;

  /// 保存服务器地址。
  Future<void> setServerUrl(String url) =>
      _prefs.setString(StorageKeys.serverUrl, url);

  /// 登录令牌，未登录时为 null。
  String? get token => _prefs.getString(StorageKeys.token);

  /// 保存登录令牌，传 null 表示清除。
  Future<void> setToken(String? token) => token == null
      ? _prefs.remove(StorageKeys.token)
      : _prefs.setString(StorageKeys.token, token);

  /// 登录用户信息，未登录时为 null。
  Map<String, dynamic>? get user {
    final json = _prefs.getString(StorageKeys.user);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// 保存登录用户信息，传 null 表示清除。
  Future<void> setUser(Map<String, dynamic>? user) => user == null
      ? _prefs.remove(StorageKeys.user)
      : _prefs.setString(StorageKeys.user, jsonEncode(user));

  /// 主题模式名（system / light / dark）。
  String get themeModeName =>
      _prefs.getString(StorageKeys.themeMode) ?? 'system';

  /// 保存主题模式名。
  Future<void> setThemeModeName(String name) =>
      _prefs.setString(StorageKeys.themeMode, name);

  /// 主题色十六进制值（不含 #），未设置时为 null。
  String? get seedColorHex => _prefs.getString(StorageKeys.seedColor);

  /// 保存主题色十六进制值，传 null 表示恢复默认。
  Future<void> setSeedColorHex(String? hex) => hex == null
      ? _prefs.remove(StorageKeys.seedColor)
      : _prefs.setString(StorageKeys.seedColor, hex);

  /// 已保存的服务器地址列表（历史连接记录）。
  List<String> get savedServers {
    final json = _prefs.getString(StorageKeys.savedServers);
    if (json == null) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // 存储数据损坏时按无记录处理
    }
    return const [];
  }

  /// 保存服务器地址列表。
  Future<void> setSavedServers(List<String> urls) =>
      _prefs.setString(StorageKeys.savedServers, jsonEncode(urls));

  /// 指定服务器的生物识别登录偏好（不含密码，密码在安全存储中）。
  BiometricLoginPrefs biometricLoginPrefs(String serverUrl) {
    final raw = _biometricPrefsMap()[normalizeServerUrl(serverUrl)];
    if (raw is Map) {
      return BiometricLoginPrefs.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
    return const BiometricLoginPrefs();
  }

  /// 保存指定服务器的生物识别登录偏好。
  Future<void> setBiometricLoginPrefs(
    String serverUrl,
    BiometricLoginPrefs prefs,
  ) {
    final map = _biometricPrefsMap()
      ..[normalizeServerUrl(serverUrl)] = prefs.toJson();
    return _prefs.setString(StorageKeys.biometric, jsonEncode(map));
  }

  Map<String, dynamic> _biometricPrefsMap() {
    final json = _prefs.getString(StorageKeys.biometric);
    if (json == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 存储数据损坏时按无记录处理
    }
    return <String, dynamic>{};
  }
}

/// 生物识别登录偏好（按服务器隔离保存，不含密码）。
class BiometricLoginPrefs {
  const BiometricLoginPrefs({
    this.enabled = false,
    this.username,
    this.declined = false,
  });

  /// 是否已启用（对应安全存储中存在凭据）。
  final bool enabled;

  /// 已保存的账号名。
  final String? username;

  /// 用户是否拒绝过启用提示（避免每次登录重复弹窗）。
  final bool declined;

  factory BiometricLoginPrefs.fromJson(Map<String, dynamic> json) =>
      BiometricLoginPrefs(
        enabled: json['enabled'] as bool? ?? false,
        username: json['username'] as String?,
        declined: json['declined'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (username != null) 'username': username,
        'declined': declined,
      };
}

/// [LocalStorage] 的 Riverpod 提供者。
///
/// 在 [main] 中完成 SharedPreferences 初始化后通过
/// `overrideWithValue` 注入真实实例。
final localStorageProvider = Provider<LocalStorage>(
  (ref) => throw UnimplementedError('localStorageProvider 未在 main 中初始化'),
);
