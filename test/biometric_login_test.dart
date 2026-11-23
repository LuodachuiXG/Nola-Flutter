import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart' show BiometricType;
import 'package:nola/core/models/blog_models.dart';
import 'package:nola/core/models/user.dart';
import 'package:nola/core/network/api_client.dart';
import 'package:nola/core/storage/local_storage.dart';
import 'package:nola/core/utils/server_url.dart';
import 'package:nola/core/network/api_exception.dart';
import 'package:nola/features/auth/data/account_verifier.dart';
import 'package:nola/features/auth/data/auth_api.dart';
import 'package:nola/features/auth/data/biometric_auth_service.dart';
import 'package:nola/features/auth/data/biometric_credential_store.dart';
import 'package:nola/features/auth/providers/biometric_login_providers.dart';
import 'package:nola/features/auth/ui/biometric_enrollment_prompt.dart';
import 'package:nola/features/auth/ui/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _server = 'http://127.0.0.1:8098';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricLoginNotifier', () {
    late LocalStorage storage;
    late _FakeBiometricAuth auth;
    late _FakeCredentialStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.setServerUrl(_server);
      auth = _FakeBiometricAuth();
      store = _FakeCredentialStore();
    });

    ProviderContainer createContainer() => ProviderContainer.test(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            biometricAuthServiceProvider.overrideWithValue(auth),
            biometricCredentialStoreProvider.overrideWithValue(store),
          ],
        );

    test('启用后加密保存凭据并可验证读取', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);

      expect(await notifier.enable('admin', 'secret'), isTrue);
      expect(auth.authenticateCalls, 1);

      final saved = store.saved[normalizeServerUrl(_server)];
      expect(saved?.username, 'admin');
      expect(saved?.password, 'secret');
      final prefs = storage.biometricLoginPrefs(_server);
      expect(prefs.enabled, isTrue);
      expect(prefs.username, 'admin');

      final state = container.read(biometricLoginProvider).requireValue;
      expect(state.enabled, isTrue);
      expect(state.declined, isFalse);

      final credential = await notifier.authenticateAndRead();
      expect(credential?.username, 'admin');
      expect(credential?.password, 'secret');
      expect(auth.authenticateCalls, 2);
    });

    test('生物验证取消时不保存凭据', () async {
      auth.authenticateResult = false;
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);

      expect(await notifier.enable('admin', 'secret'), isFalse);
      expect(store.saved, isEmpty);
      expect(storage.biometricLoginPrefs(_server).enabled, isFalse);
    });

    test('生物验证取消时读取凭据返回 null', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.enable('admin', 'secret');

      auth.authenticateResult = false;
      expect(await notifier.authenticateAndRead(), isNull);
    });

    test('凭据缺失时清除启用状态但不标记拒绝', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.enable('admin', 'secret');

      store.saved.clear();
      expect(await notifier.authenticateAndRead(), isNull);
      final prefs = storage.biometricLoginPrefs(_server);
      expect(prefs.enabled, isFalse);
      expect(prefs.declined, isFalse);
      final state = container.read(biometricLoginProvider).requireValue;
      expect(state.enabled, isFalse);
      expect(state.declined, isFalse);
    });

    test('设备不支持时无法启用', () async {
      auth.supported = false;
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);

      expect(await notifier.enable('admin', 'secret'), isFalse);
      expect(store.saved, isEmpty);
    });

    test('关闭后清除凭据并标记为已拒绝', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.enable('admin', 'secret');

      await notifier.disable();
      expect(store.saved, isEmpty);
      final prefs = storage.biometricLoginPrefs(_server);
      expect(prefs.enabled, isFalse);
      expect(prefs.declined, isTrue);
      final state = container.read(biometricLoginProvider).requireValue;
      expect(state.enabled, isFalse);
      expect(state.username, isNull);
    });

    test('记录拒绝后状态为 declined', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);

      await notifier.markDeclined();
      expect(storage.biometricLoginPrefs(_server).declined, isTrue);
      expect(
        container.read(biometricLoginProvider).requireValue.declined,
        isTrue,
      );
    });

    test('手动登录仅同步同一账号的密码', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.enable('admin', 'old');

      await notifier.updateSavedPassword('other', 'hacked');
      expect(store.saved[normalizeServerUrl(_server)]?.password, 'old');

      await notifier.updateSavedPassword('admin', 'new');
      expect(store.saved[normalizeServerUrl(_server)]?.password, 'new');
    });

    test('切换服务器后按服务器隔离状态', () async {
      final container = createContainer();
      await container.read(biometricLoginProvider.future);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.enable('admin', 'secret');

      await storage.setServerUrl('http://192.168.1.2:8098');
      container.invalidate(biometricLoginProvider);
      final switched = await container.read(biometricLoginProvider.future);
      expect(switched.enabled, isFalse);
      expect(switched.username, isNull);

      await storage.setServerUrl(_server);
      container.invalidate(biometricLoginProvider);
      final back = await container.read(biometricLoginProvider.future);
      expect(back.enabled, isTrue);
      expect(back.username, 'admin');
    });
  });

  test('账号密码校验走独立请求并透传错误信息', () async {
    final verifier = AccountVerifier(
      createDio: () => Dio()..httpClientAdapter = _FakeAccountAdapter(),
    );

    await verifier.verify(
      serverUrl: 'http://localhost',
      username: 'admin',
      password: 'right',
    );
    await expectLater(
      verifier.verify(
        serverUrl: 'http://localhost',
        username: 'admin',
        password: 'wrong',
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 401)
            .having((error) => error.message, 'message', '密码错误'),
      ),
    );
  });

  group('登录页生物识别', () {
    testWidgets('已保存凭据时进入登录页自动生物识别登录', (tester) async {
      final env = await _pumpLogin(tester, enabled: true);

      expect(env.auth.authenticateCalls, 1);
      expect(env.api.loginCalls, 1);
      expect(env.api.lastUsername, 'admin');
      expect(env.api.lastPassword, 'secret');
      expect(find.text('dashboard'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('登录成功后提示启用生物识别并保存凭据', (tester) async {
      final env = await _pumpLogin(tester, enabled: false);

      await tester.enterText(find.byType(TextFormField).at(0), 'admin');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('启用生物识别登录？'), findsOneWidget);
      await tester.tap(find.text('启用'));
      await tester.pumpAndSettle();

      expect(env.auth.authenticateCalls, 1);
      final saved = env.store.saved[normalizeServerUrl(_server)];
      expect(saved?.username, 'admin');
      expect(saved?.password, 'secret');
      expect(env.storage.biometricLoginPrefs(_server).enabled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// 搭建登录页与最小路由，返回测试环境。
Future<
    ({
      LocalStorage storage,
      _FakeBiometricAuth auth,
      _FakeCredentialStore store,
      _FakeAuthApi api,
    })> _pumpLogin(
  WidgetTester tester, {
  required bool enabled,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorage(await SharedPreferences.getInstance());
  await storage.setServerUrl(_server);
  if (enabled) {
    await storage.setBiometricLoginPrefs(
      _server,
      const BiometricLoginPrefs(enabled: true, username: 'admin'),
    );
  }

  final auth = _FakeBiometricAuth();
  final store = _FakeCredentialStore();
  if (enabled) {
    await store.save(
      _server,
      BiometricCredential(
        username: 'admin',
        password: 'secret',
        savedAt: DateTime.now(),
      ),
    );
  }
  final api = _FakeAuthApi();

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const BiometricEnrollmentPrompt(
          child: Scaffold(body: Center(child: Text('dashboard'))),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        authApiProvider.overrideWithValue(api),
        biometricAuthServiceProvider.overrideWithValue(auth),
        biometricCredentialStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return (storage: storage, auth: auth, store: store, api: api);
}

class _FakeBiometricAuth implements BiometricAuthService {
  bool supported = true;
  bool authenticateResult = true;
  int authenticateCalls = 0;

  @override
  Future<BiometricAvailability> availability() async => supported
      ? const BiometricAvailability(
          supported: true,
          types: [BiometricType.fingerprint],
        )
      : BiometricAvailability.unsupported;

  @override
  Future<bool> authenticate(String reason) async {
    authenticateCalls++;
    return authenticateResult;
  }
}

class _FakeCredentialStore implements BiometricCredentialStore {
  final Map<String, BiometricCredential> saved = {};

  @override
  Future<void> save(String serverUrl, BiometricCredential credential) async {
    saved[normalizeServerUrl(serverUrl)] = credential;
  }

  @override
  Future<BiometricCredential?> read(String serverUrl) async =>
      saved[normalizeServerUrl(serverUrl)];

  @override
  Future<void> delete(String serverUrl) async {
    saved.remove(normalizeServerUrl(serverUrl));
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(ApiClient(Dio()));

  int loginCalls = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<BlogInfo?> blogInfo() async =>
      const BlogInfo(title: '测试博客', subtitle: '测试副标题');

  @override
  Future<UserInfo> login(String username, String password) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    return UserInfo(
      userId: 1,
      username: username,
      email: 'admin@example.com',
      displayName: '管理员',
      createDate: 0,
      token: 'test-token',
    );
  }
}


/// 模拟登录接口响应，避免测试环境拦截真实网络请求。
class _FakeAccountAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    final password = data is Map ? data['password'] : null;
    return ResponseBody.fromString(
      password == 'wrong'
          ? '{"code":401,"errMsg":"密码错误"}'
          : '{"code":200,"data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
