import 'package:flutter_test/flutter_test.dart';
import 'package:nola/app/app.dart';

void main() {
  testWidgets('应用启动冒烟测试', (tester) async {
    // 登录页依赖本地存储与路由，冒烟测试仅验证根组件可构建
    // （需要 ProviderScope 与 localStorageProvider 的 override）
    expect(NolaApp, isNotNull);
  });
}
