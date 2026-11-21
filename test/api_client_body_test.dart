import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/network/api_client.dart';

/// 回归测试：裸 `List<int>` 请求体必须以 `application/json` 的 JSON 数组发送。
///
/// 背景：dio 的 ImplyContentTypeInterceptor 无法为 `List<int>` 推断
/// Content-Type（视为可能的原始字节），不显式声明时请求体不会被
/// jsonEncode，后端按 JSON 解析会报“请求参数不匹配”。
void main() {
  late HttpServer server;
  late ApiClient client;
  String? receivedContentType;
  String? receivedBody;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      receivedContentType = request.headers.value(HttpHeaders.contentTypeHeader);
      receivedBody = await utf8.decoder.bind(request).join();
      // 返回 Nola 统一响应结构
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'code': 200, 'errMsg': null, 'data': true}),
      );
      await request.response.close();
    });
    client = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}')),
    );
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('DELETE 携带 List<int> 时以 JSON 数组发送', () async {
    final result = await client.delete<bool>(
      '/admin/menu/item',
      body: [1, 2, 3],
      parse: (data) => data is bool ? data : false,
    );
    expect(result, isTrue);
    expect(receivedBody, '[1,2,3]');
    expect(receivedContentType, contains('application/json'));
  });

  test('PUT 携带 List<int> 时以 JSON 数组发送', () async {
    final result = await client.put<bool>(
      '/admin/post/recycle',
      body: [42],
      parse: (data) => data is bool ? data : false,
    );
    expect(result, isTrue);
    expect(receivedBody, '[42]');
    expect(receivedContentType, contains('application/json'));
  });

  test('POST 携带 List<int> 时以 JSON 数组发送', () async {
    final result = await client.post<bool>(
      '/x',
      body: [7, 8],
      parse: (data) => data is bool ? data : false,
    );
    expect(result, isTrue);
    expect(receivedBody, '[7,8]');
    expect(receivedContentType, contains('application/json'));
  });

  test('Map 请求体正常以 JSON 发送', () async {
    final result = await client.post<bool>(
      '/admin/user/login',
      body: <String, dynamic>{'username': 'nola', 'password': 'pwd'},
      parse: (data) => data is bool ? data : false,
    );
    expect(result, isTrue);
    expect(receivedBody, '{"username":"nola","password":"pwd"}');
    expect(receivedContentType, contains('application/json'));
  });
}
