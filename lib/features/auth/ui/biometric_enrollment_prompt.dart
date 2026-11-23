import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/dialogs.dart';
import '../providers/biometric_login_providers.dart';

/// 控制台内的生物识别启用提示监听。
///
/// 登录页在登录成功后写入待处理请求并跳转，进入控制台后在此弹出提示，
/// 避免登录页路由切换把弹窗一起销毁。
class BiometricEnrollmentPrompt extends ConsumerStatefulWidget {
  const BiometricEnrollmentPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricEnrollmentPrompt> createState() =>
      _BiometricEnrollmentPromptState();
}

class _BiometricEnrollmentPromptState
    extends ConsumerState<BiometricEnrollmentPrompt> {
  bool _handling = false;

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(biometricEnrollmentOfferProvider);
    if (offer != null && !_handling) {
      // 进入控制台首帧后再弹窗，确保 Navigator / Overlay 已就绪
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handle(offer);
      });
    }
    return widget.child;
  }

  Future<void> _handle(BiometricEnrollmentOffer offer) async {
    if (_handling || !mounted) return;
    _handling = true;
    // 先捕获 notifier 并消费请求，避免等待过程中组件销毁导致 ref 失效
    final notifier = ref.read(biometricLoginProvider.notifier);
    final stateFuture = ref.read(biometricLoginProvider.future);
    ref.read(biometricEnrollmentOfferProvider.notifier).clear();
    try {
      final state = await stateFuture;
      if (!mounted || !state.supported) return;
      if (state.enabled) {
        // 已启用：账号一致时静默同步最新密码
        await notifier.updateSavedPassword(offer.username, offer.password);
        return;
      }
      if (state.declined) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('启用生物识别登录？'),
          content: const Text(
            '可将本次登录的账号密码加密保存在本机，'
            '下次使用 Face ID、指纹或设备密码快速登录。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('暂不开启'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('启用'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        await notifier.markDeclined();
        return;
      }
      final enabled = await notifier.enable(offer.username, offer.password);
      if (!mounted) return;
      if (enabled) {
        showGlobalSnack('已启用生物识别登录');
      } else {
        showGlobalSnack('未通过身份验证，暂未启用生物识别登录', error: true);
      }
    } catch (_) {
      // 提示流程失败不影响控制台使用
    } finally {
      _handling = false;
    }
  }
}
