import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/blog_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sse_client.dart';

/// 概览 API。
class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  /// 获取博客概览数据。
  Future<Overview> overview() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/overview',
      parse: (data) => Map<String, dynamic>.from(data as Map),
    );
    if (data == null) {
      throw StateError('概览数据缺失');
    }
    return Overview.fromJson(data);
  }
}

/// [DashboardApi] 提供者。
final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(ref.watch(apiClientProvider));
});

/// 博客概览数据。
final overviewProvider = FutureProvider.autoDispose<Overview>((ref) {
  return ref.watch(dashboardApiProvider).overview();
});

/// 实时在线人数（SSE 订阅）。
///
/// 连接异常时返回 null 值；重新监听会重新建立连接。
final onlineCountProvider = StreamProvider.autoDispose<int>((ref) {
  final sse = ref.watch(sseClientProvider);
  return sse.events('/admin/overview/online').map((data) {
    final json = jsonDecode(data);
    if (json is Map) {
      return OnlineCount.fromJson(Map<String, dynamic>.from(json)).count;
    }
    return 0;
  });
});
