import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/blog_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/server_probe.dart';
import '../../../core/network/sse_client.dart';
import '../../../core/storage/local_storage.dart';

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

/// 服务器延迟测量结果。
class ServerLatency {
  const ServerLatency({required this.available, this.latencyMs});

  const ServerLatency.unreachable() : this(available: false);

  /// 服务器是否可达（且为 Nola 服务）。
  final bool available;

  /// 请求公开接口 `/api/config/blog` 的往返耗时（毫秒）。
  final int? latencyMs;
}

/// 周期探测服务器延迟：每 10 秒请求一次公开接口并统计往返耗时。
///
/// 离开概览页（autoDispose）后自动停止探测。
final serverLatencyProvider =
    StreamProvider.autoDispose<ServerLatency>((ref) async* {
  final serverUrl = ref.watch(localStorageProvider).serverUrl;
  while (true) {
    final watch = Stopwatch()..start();
    try {
      final result = await ServerProbe.probe(serverUrl);
      watch.stop();
      yield result.available
          ? ServerLatency(available: true, latencyMs: watch.elapsedMilliseconds)
          : const ServerLatency.unreachable();
    } catch (_) {
      yield const ServerLatency.unreachable();
    }
    await Future<void>.delayed(const Duration(seconds: 10));
  }
});
