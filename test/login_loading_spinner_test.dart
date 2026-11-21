import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nola/core/models/blog_models.dart';
import 'package:nola/core/network/api_client.dart';
import 'package:nola/core/storage/local_storage.dart';
import 'package:nola/features/auth/data/auth_api.dart';
import 'package:nola/features/auth/ui/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// blogInfo 永不完成的 API 桩：让加载态持续存在以便断言。
class NeverAuthApi extends AuthApi {
  NeverAuthApi() : super(ApiClient(Dio()));

  @override
  Future<BlogInfo?> blogInfo() => Completer<BlogInfo?>().future;
}

/// 登录页加载进度条回归测试。
///
/// 外层 Column 使用 crossAxisAlignment: stretch，此前进度条被水平
/// 拉伸为椭圆；修复后应以 Center 提供松约束，保持 1:1 正圆并居中。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          authApiProvider.overrideWith((ref) => NeverAuthApi()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  /// 博客信息加载中的进度条（Center 祖先定位，
  /// 与服务器状态图标的小进度条区分开）。
  Finder loadingSpinner() => find.byElementPredicate((element) {
        if (element.widget is! CircularProgressIndicator) return false;
        // 目标链路为 Center -> Padding -> CircularProgressIndicator
        final ancestors = <Widget>[];
        element.visitAncestorElements((ancestor) {
          ancestors.add(ancestor.widget);
          return ancestors.length < 2;
        });
        return ancestors.length >= 2 &&
            ancestors[0] is Padding &&
            ancestors[1] is Center;
      });

  testWidgets('加载进度条保持 1:1 圆形', (tester) async {
    await pumpLogin(tester);

    final size = tester.getSize(loadingSpinner());
    expect(
      size.width,
      equals(size.height),
      reason: '进度条应为正方形（圆形），不能被拉伸为椭圆',
    );
    expect(size.width, 36.0);
  });

  testWidgets('加载进度条水平居中', (tester) async {
    await pumpLogin(tester);

    final screenCenter = tester.getCenter(find.byType(LoginScreen));
    final spinnerCenter = tester.getCenter(loadingSpinner());
    expect(
      spinnerCenter.dx,
      closeTo(screenCenter.dx, 0.5),
      reason: '进度条应水平居中显示',
    );
  });
}
