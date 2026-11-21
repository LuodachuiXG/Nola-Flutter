import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/blog_models.dart';
import '../data/setting_api.dart';

/// 博客信息（管理端）。
final blogInfoProvider = FutureProvider.autoDispose<BlogInfo?>((ref) {
  return ref.watch(settingApiProvider).blogInfo();
});

/// 备案信息。
final icpProvider = FutureProvider.autoDispose<ICPFiling?>((ref) {
  return ref.watch(settingApiProvider).icp();
});
