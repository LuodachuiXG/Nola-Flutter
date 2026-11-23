import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/server_url.dart';

/// 生物识别登录保存的账号凭据。
class BiometricCredential {
  const BiometricCredential({
    required this.username,
    required this.password,
    required this.savedAt,
  });

  final String username;
  final String password;
  final DateTime savedAt;

  factory BiometricCredential.fromJson(Map<String, dynamic> json) =>
      BiometricCredential(
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as num?)?.toInt() ?? 0,
        ),
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };
}

/// 凭据安全存储抽象（便于测试替换）。
abstract class BiometricCredentialStore {
  Future<void> save(String serverUrl, BiometricCredential credential);

  Future<BiometricCredential?> read(String serverUrl);

  Future<void> delete(String serverUrl);
}

/// 基于系统安全存储的实现：iOS / macOS Keychain、Android Keystore。
///
/// - Apple 使用 `unlocked_this_device`（不随 iCloud 同步、不迁移设备）；
/// - macOS 关闭 Data Protection Keychain，避免引入 Keychain Sharing
///   权限与描述文件要求，数据仍由系统钥匙串加密保存；
/// - 读取前由 [BiometricAuthService] 统一要求生物识别 / 设备密码验证。
class SecureBiometricCredentialStore implements BiometricCredentialStore {
  SecureBiometricCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
                usesDataProtectionKeychain: false,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _keyPrefix = 'nola.biometric.credential.';

  String _key(String serverUrl) =>
      '$_keyPrefix${normalizeServerUrl(serverUrl)}';

  @override
  Future<void> save(String serverUrl, BiometricCredential credential) =>
      _storage.write(
        key: _key(serverUrl),
        value: jsonEncode(credential.toJson()),
      );

  @override
  Future<BiometricCredential?> read(String serverUrl) async {
    final raw = await _storage.read(key: _key(serverUrl));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return BiometricCredential.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // 数据损坏时按未保存处理
    }
    return null;
  }

  @override
  Future<void> delete(String serverUrl) =>
      _storage.delete(key: _key(serverUrl));
}
