import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 生物识别 / 设备密码可用性。
class BiometricAvailability {
  const BiometricAvailability({
    required this.supported,
    this.types = const <BiometricType>[],
  });

  /// 设备是否具备可用的身份验证方式（生物识别或锁屏密码）。
  final bool supported;

  /// 已录入的生物识别类型。
  final List<BiometricType> types;

  /// 不支持时的空结果。
  static const unsupported = BiometricAvailability(supported: false);
}

/// 生物识别 / 设备密码验证服务抽象（便于测试替换）。
abstract class BiometricAuthService {
  /// 检测当前设备是否支持身份验证。
  Future<BiometricAvailability> availability();

  /// 拉起系统验证；[reason] 为系统弹窗上的说明文案。
  Future<bool> authenticate(String reason);
}

/// 基于 local_auth 的实现，仅 Android / iOS / macOS 生效。
class LocalBiometricAuthService implements BiometricAuthService {
  LocalBiometricAuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  /// 当前平台是否支持本地身份验证。
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<BiometricAvailability> availability() async {
    if (!isSupportedPlatform) return BiometricAvailability.unsupported;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return BiometricAvailability.unsupported;
      final types = await _localAuth.getAvailableBiometrics();
      return BiometricAvailability(supported: true, types: types);
    } catch (_) {
      return BiometricAvailability.unsupported;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    if (!isSupportedPlatform) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        // 允许回退到设备密码 / PIN
        biometricOnly: false,
        // 验证期间切到后台后自动恢复
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // 取消 / 锁定 / 硬件不可用等情况统一按未通过处理
      return false;
    }
  }
}
