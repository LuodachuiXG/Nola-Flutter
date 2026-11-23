import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/constants/app_constants.dart';
import 'package:nola/features/settings/providers/app_info_providers.dart';
import 'package:nola/features/settings/ui/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _info = AppBuildInfo(
  version: '1.2.3',
  buildNumber: '45',
  buildMode: 'Release',
  platform: 'macOS · arm64',
  osVersion: 'Version 27.0.1 (Build 26A434)',
  dartVersion: '3.13.5',
);

void main() {
  late _FakeUrlLauncherPlatform launcher;

  setUp(() {
    launcher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('关于分组展示版本与构建信息', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBuildInfoProvider.overrideWith((ref) async => _info),
        ],
        child: const MaterialApp(home: Scaffold(body: AppInfoSection())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('应用版本'), findsOneWidget);
    expect(find.text('1.2.3 (45)'), findsOneWidget);
    expect(find.text('构建模式'), findsOneWidget);
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('运行平台'), findsOneWidget);
    expect(find.text('macOS · arm64'), findsOneWidget);
    expect(find.text('系统版本'), findsOneWidget);
    expect(find.text('Version 27.0.1 (Build 26A434)'), findsOneWidget);
    expect(find.text('Dart 版本'), findsOneWidget);
    expect(find.text('3.13.5'), findsOneWidget);
  });

  test('构建信息来自应用包与运行时', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Nola',
      packageName: 'com.example.nola',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    final container = ProviderContainer.test();
    final info = await container.read(appBuildInfoProvider.future);

    expect(info.versionLabel, '1.2.3 (45)');
    expect(info.buildMode, 'Debug');
    expect(info.platform, isNotEmpty);
    expect(info.osVersion, isNotNull);
    expect(info.dartVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  testWidgets('开源地址分组展示并可打开链接', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OpenSourceSection())),
    );

    expect(find.text('开源地址'), findsOneWidget);
    expect(find.text('Flutter 客户端'), findsOneWidget);
    expect(find.text('Nola 博客'), findsOneWidget);
    expect(find.text(kFlutterClientRepoUrl), findsOneWidget);
    expect(find.text(kNolaRepoUrl), findsOneWidget);

    await tester.tap(find.text('Flutter 客户端'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nola 博客'));
    await tester.pumpAndSettle();

    expect(launcher.launchedUrls, [kFlutterClientRepoUrl, kNolaRepoUrl]);
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
