import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/network/server_probe.dart';

/// 服务器连接探测回归测试：验证「可达性 / Nola 服务识别 / 可用性」判定。
void main() {
  late HttpServer server;
  var body = <String, Object?>{'code': 200, 'errMsg': null, 'data': null};
  var contentType = 'application/json';

  setUp(() async {
    body = {'code': 200, 'errMsg': null, 'data': null};
    contentType = 'application/json';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        '$contentType; charset=utf-8',
      );
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  String serverUrl() => 'http://127.0.0.1:${server.port}';

  test('Nola 服务（code=200）判定为可用', () async {
    final result = await ServerProbe.probe(serverUrl());
    expect(result.reachable, isTrue);
    expect(result.isNola, isTrue);
    expect(result.available, isTrue);
    expect(result.success, isTrue);
  });

  test('博客未初始化（data=null）同样判定为可用', () async {
    body = {'code': 200, 'errMsg': null, 'data': null};
    final result = await ServerProbe.probe(serverUrl());
    expect(result.available, isTrue);
  });

  test('Nola 服务响应异常（code!=200）判定为 Nola 但不可用', () async {
    body = {'code': 500, 'errMsg': '服务器内部错误', 'data': null};
    final result = await ServerProbe.probe(serverUrl());
    expect(result.reachable, isTrue);
    expect(result.isNola, isTrue);
    expect(result.available, isFalse);
    expect(result.message, contains('500'));
  });

  test('非 Nola 服务（HTML 响应）判定为不是 Nola', () async {
    contentType = 'text/html';
    final result = await ServerProbe.probe(serverUrl());
    expect(result.reachable, isTrue);
    expect(result.isNola, isFalse);
    expect(result.available, isFalse);
    expect(result.message, contains('不是 Nola 服务'));
  });

  test('地址结尾斜杠会被规范化', () async {
    final result = await ServerProbe.probe('${serverUrl()}/');
    expect(result.available, isTrue);
  });

  test('不可达地址返回连接失败', () async {
    // 绑定一个端口后立即释放，保证没有服务监听
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = dead.port;
    await dead.close();

    final result = await ServerProbe.probe('http://127.0.0.1:$port');
    expect(result.reachable, isFalse);
    expect(result.isNola, isFalse);
    expect(result.available, isFalse);
    expect(result.message, contains('无法连接'));
  });
}
