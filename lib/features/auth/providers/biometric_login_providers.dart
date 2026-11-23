import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/storage/local_storage.dart';
import '../data/biometric_auth_service.dart';
import '../data/biometric_credential_store.dart';

/// 生物识别验证服务（测试可替换）。
final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => LocalBiometricAuthService(),
);

/// 凭据安全存储（测试可替换）。
final biometricCredentialStoreProvider = Provider<BiometricCredentialStore>(
  (ref) => SecureBiometricCredentialStore(),
);

/// 生物识别登录状态。
class BiometricLoginState {
  const BiometricLoginState({
    required this.serverUrl,
    required this.supported,
    required this.enabled,
    required this.declined,
    this.username,
    this.types = const <BiometricType>[],
  });

  /// 状态所属的服务器地址。
  final String serverUrl;

  /// 当前设备是否支持生物识别 / 设备密码。
  final bool supported;

  /// 是否已保存凭据并启用。
  final bool enabled;

  /// 用户是否拒绝过启用提示。
  final bool declined;

  /// 已保存的账号名。
  final String? username;

  /// 已录入的生物识别类型。
  final List<BiometricType> types;

  /// 是否包含人脸识别。
  bool get usesFace => types.contains(BiometricType.face);

  /// 是否包含指纹识别。
  bool get usesFingerprint => types.contains(BiometricType.fingerprint);

  /// 生物识别登录按钮文案。
  String get loginLabel {
    if (usesFace) {
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? '使用 Face ID 登录'
          : '使用人脸识别登录';
    }
    if (usesFingerprint) return '使用指纹登录';
    if (types.isNotEmpty) return '使用生物识别登录';
    return '使用设备密码登录';
  }

  BiometricLoginState copyWith({
    bool? enabled,
    bool? declined,
    String? username,
    bool clearUsername = false,
  }) =>
      BiometricLoginState(
        serverUrl: serverUrl,
        supported: supported,
        enabled: enabled ?? this.enabled,
        declined: declined ?? this.declined,
        username: clearUsername ? null : (username ?? this.username),
        types: types,
      );
}

/// 生物识别登录状态管理：按当前服务器读取偏好并驱动启用 / 关闭。
///
/// 登录页切换服务器后需要调用 `ref.invalidate(biometricLoginProvider)`
/// 重新加载对应服务器的状态。
class BiometricLoginNotifier extends AsyncNotifier<BiometricLoginState> {
  @override
  Future<BiometricLoginState> build() async {
    final storage = ref.watch(localStorageProvider);
    final serverUrl = storage.serverUrl;
    final prefs = storage.biometricLoginPrefs(serverUrl);
    final availability =
        await ref.read(biometricAuthServiceProvider).availability();
    final enabled = prefs.enabled && availability.supported;
    if (prefs.enabled && !availability.supported) {
      // 设备已不支持（硬件变更 / 凭据被清理），清除启用状态
      await storage.setBiometricLoginPrefs(
        serverUrl,
        const BiometricLoginPrefs(declined: true),
      );
    }
    return BiometricLoginState(
      serverUrl: serverUrl,
      supported: availability.supported,
      enabled: enabled,
      declined: prefs.declined || (prefs.enabled && !availability.supported),
      username: enabled ? prefs.username : null,
      types: availability.types,
    );
  }

  BiometricLoginState? get _current => state.value;

  /// 生物验证并读取已保存凭据；取消验证或未启用时返回 null。
  Future<BiometricCredential?> authenticateAndRead() async {
    final current = _current;
    if (current == null || !current.enabled) return null;
    final authenticated = await ref
        .read(biometricAuthServiceProvider)
        .authenticate('验证身份以使用已保存的账号密码登录');
    if (!authenticated) return null;
    BiometricCredential? credential;
    try {
      credential = await ref
          .read(biometricCredentialStoreProvider)
          .read(current.serverUrl);
    } catch (_) {
      credential = null;
    }
    if (credential == null ||
        credential.username.isEmpty ||
        credential.password.isEmpty) {
      // 凭据已失效：清除启用状态，但允许下次手动登录后重新提示启用
      await clearInvalid();
      return null;
    }
    return credential;
  }

  /// 启用生物识别登录：先通过系统验证，再加密保存账号密码。
  Future<bool> enable(String username, String password) async {
    final current = _current;
    if (current == null || !current.supported) return false;
    final authenticated = await ref
        .read(biometricAuthServiceProvider)
        .authenticate('验证身份以启用生物识别登录');
    if (!authenticated) return false;
    try {
      await ref.read(biometricCredentialStoreProvider).save(
            current.serverUrl,
            BiometricCredential(
              username: username,
              password: password,
              savedAt: DateTime.now(),
            ),
          );
      await ref.read(localStorageProvider).setBiometricLoginPrefs(
            current.serverUrl,
            BiometricLoginPrefs(enabled: true, username: username),
          );
    } catch (_) {
      return false;
    }
    state = AsyncData(
      current.copyWith(
        enabled: true,
        declined: false,
        username: username,
      ),
    );
    return true;
  }

  /// 关闭生物识别登录并清除已保存凭据。
  ///
  /// 同时标记为已拒绝，避免下次手动登录后再次弹出启用提示；
  /// 用户仍可在设置页重新开启。
  Future<void> disable() async {
    final current = _current;
    if (current == null) return;
    try {
      await ref
          .read(biometricCredentialStoreProvider)
          .delete(current.serverUrl);
    } catch (_) {
      // 删除失败也继续清除启用状态
    }
    await ref.read(localStorageProvider).setBiometricLoginPrefs(
          current.serverUrl,
          const BiometricLoginPrefs(declined: true),
        );
    state = AsyncData(
      current.copyWith(
        enabled: false,
        declined: true,
        clearUsername: true,
      ),
    );
  }

  /// 清除失效的凭据（如系统清理、服务端密码已变更）。
  ///
  /// 与 [disable] 不同，不标记 declined：用户下次手动登录后仍会收到启用提示。
  Future<void> clearInvalid() async {
    final current = _current;
    if (current == null) return;
    try {
      await ref
          .read(biometricCredentialStoreProvider)
          .delete(current.serverUrl);
    } catch (_) {
      // 删除失败也继续清除启用状态
    }
    await ref.read(localStorageProvider).setBiometricLoginPrefs(
          current.serverUrl,
          const BiometricLoginPrefs(),
        );
    state = AsyncData(
      current.copyWith(
        enabled: false,
        declined: false,
        clearUsername: true,
      ),
    );
  }

  /// 记录用户拒绝了启用提示，下次登录不再重复询问。
  Future<void> markDeclined() async {
    final current = _current;
    if (current == null) return;
    await ref.read(localStorageProvider).setBiometricLoginPrefs(
          current.serverUrl,
          const BiometricLoginPrefs(declined: true),
        );
    state = AsyncData(current.copyWith(declined: true));
  }

  /// 手动登录成功后同步最新密码（仅账号一致时）。
  Future<void> updateSavedPassword(String username, String password) async {
    final current = _current;
    if (current == null || !current.enabled) return;
    if (current.username != null && current.username != username) return;
    try {
      await ref.read(biometricCredentialStoreProvider).save(
            current.serverUrl,
            BiometricCredential(
              username: username,
              password: password,
              savedAt: DateTime.now(),
            ),
          );
      await ref.read(localStorageProvider).setBiometricLoginPrefs(
            current.serverUrl,
            BiometricLoginPrefs(enabled: true, username: username),
          );
    } catch (_) {
      // 写入失败时清除启用状态，避免保留不可用的凭据
      await clearInvalid();
    }
  }

  /// 修改密码后更新已保存凭据；失败时关闭生物识别登录。
  Future<void> updatePassword(String password) async {
    final current = _current;
    final username = current?.username;
    if (current == null || !current.enabled || username == null) return;
    await updateSavedPassword(username, password);
  }
}

/// 生物识别登录状态提供者。
final biometricLoginProvider =
    AsyncNotifierProvider<BiometricLoginNotifier, BiometricLoginState>(
  BiometricLoginNotifier.new,
);

/// 登录成功后待处理的生物识别启用请求。
///
/// 仅保存在内存中（含明文密码），进入控制台提示后立即清除；
/// 用于避开登录页到控制台路由切换导致弹窗被销毁的问题。
class BiometricEnrollmentOffer {
  const BiometricEnrollmentOffer({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

/// 待处理启用请求管理。
class BiometricEnrollmentOfferNotifier
    extends Notifier<BiometricEnrollmentOffer?> {
  @override
  BiometricEnrollmentOffer? build() => null;

  void offer(String username, String password) {
    state = BiometricEnrollmentOffer(username: username, password: password);
  }

  void clear() => state = null;
}

/// 待处理生物识别启用请求提供者。
final biometricEnrollmentOfferProvider = NotifierProvider<
    BiometricEnrollmentOfferNotifier, BiometricEnrollmentOffer?>(
  BiometricEnrollmentOfferNotifier.new,
);
