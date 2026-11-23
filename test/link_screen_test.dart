import 'package:dio/dio.dart' show Dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/models/common.dart';
import 'package:nola/core/models/diary.dart';
import 'package:nola/core/models/enums.dart';
import 'package:nola/core/network/api_client.dart';
import 'package:nola/features/links/data/link_api.dart';
import 'package:nola/features/links/ui/link_screen.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  late _FakeUrlLauncherPlatform launcher;

  setUp(() {
    launcher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('点击友链卡片用浏览器打开链接', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [linkApiProvider.overrideWithValue(_FakeLinkApi())],
        child: const MaterialApp(home: LinkScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('友链 A'), findsOneWidget);
    expect(find.text('https://a.example.com'), findsOneWidget);

    await tester.tap(find.text('友链 A'));
    await tester.pumpAndSettle();
    expect(launcher.launchedUrls, ['https://a.example.com']);

    // 未带协议头的地址按 https 补全后再打开
    await tester.tap(find.text('友链 B'));
    await tester.pumpAndSettle();
    expect(launcher.launchedUrls.last, 'https://b.example.com');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

class _FakeLinkApi extends LinkApi {
  _FakeLinkApi() : super(ApiClient(Dio()));

  @override
  Future<Pager<Link>> links({
    required int page,
    required int size,
    LinkSort? sort,
  }) async {
    return Pager<Link>(
      page: 1,
      size: size,
      totalData: 2,
      totalPages: 1,
      data: [
        Link.fromJson({
          'linkId': 1,
          'displayName': '友链 A',
          'url': 'https://a.example.com',
        }),
        Link.fromJson({
          'linkId': 2,
          'displayName': '友链 B',
          'url': 'b.example.com',
        }),
      ],
    );
  }
}
