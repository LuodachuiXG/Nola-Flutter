import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 最小 SSE（Server-Sent Events）客户端。
///
/// 基于 dio 的流式响应实现，供管理端订阅实时数据
/// （如博客在线人数 `/admin/overview/online`）。
/// 服务器心跳帧（data 为 `ping`）会被自动过滤。
class SseClient {
  SseClient(this._dio);

  final Dio _dio;

  /// 订阅指定路径，返回每个事件的 data 文本流。
  ///
  /// 主动取消订阅即可断开连接；连接异常时流会以错误结束。
  Stream<String> events(String path) {
    final controller = StreamController<String>();
    StreamSubscription<Uint8List>? subscription;

    Future<void> start() async {
      try {
        final response = await _dio.get<ResponseBody>(
          path,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            // SSE 为长连接，不限制响应超时
            receiveTimeout: null,
          ),
        );
        final body = response.data;
        if (body == null) {
          await controller.close();
          return;
        }
        var buffer = '';
        subscription = body.stream.listen(
          (chunk) {
            buffer += utf8.decode(chunk, allowMalformed: true);
            // SSE 事件以空行分隔
            while (true) {
              final index = buffer.indexOf('\n\n');
              if (index < 0) break;
              final event = buffer.substring(0, index);
              buffer = buffer.substring(index + 2);
              final data = _parseEventData(event);
              if (data != null && data != 'ping') {
                controller.add(data);
              }
            }
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: true,
        );
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
        await controller.close();
      }
    }

    controller.onCancel = () async {
      await subscription?.cancel();
    };

    start();
    return controller.stream;
  }

  /// 提取事件文本中的 data 字段（多行 data 合并）。
  String? _parseEventData(String event) {
    final lines = event.split('\n');
    final dataLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return null;
    return dataLines.join('\n');
  }
}

/// [SseClient] 的 Riverpod 提供者，复用全局 dio 实例。
final sseClientProvider = Provider<SseClient>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SseClient(apiClient.dio);
});
