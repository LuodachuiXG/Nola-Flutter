import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/server_probe.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/formatters.dart' show isValidEmail;
import '../../../shared/widgets/dialogs.dart';
import '../../../core/models/blog_models.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';
import '../providers/biometric_login_providers.dart';

/// 登录页模式。
enum _LoginMode {
  /// 登录。
  login,

  /// 初始化博客。
  createBlog,

  /// 初始化管理员。
  createAdmin,
}

/// 登录与博客初始化页面。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _blogTitleController = TextEditingController();
  final _blogSubtitleController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminDisplayNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminPasswordAgainController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _blogFormKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();

  _LoginMode _mode = _LoginMode.login;
  BlogInfo? _blogInfo;
  bool _loadingBlogInfo = true;
  bool _submitting = false;
  bool _obscurePassword = true;

  // 服务器连接状态与管理
  bool _connected = false;
  String? _connectError;
  bool _serverPanelOpen = false;
  List<String> _savedServers = [];
  bool _probing = false;
  String? _probeError;

  /// 生物识别自动登录是否已尝试（每次进入页面仅自动弹一次）。
  bool _biometricAutoTried = false;

  /// 生物识别验证 / 登录进行中。
  bool _biometricRunning = false;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    _savedServers = storage.savedServers;
    // 首次使用时把默认服务器加入保存列表，保证列表不为空
    if (_savedServers.isEmpty) {
      _savedServers = [storage.serverUrl];
      storage.setSavedServers(_savedServers);
    }
    _refreshBlogInfo();
  }

  @override
  void dispose() {
    for (final controller in [
      _usernameController,
      _passwordController,
      _serverUrlController,
      _blogTitleController,
      _blogSubtitleController,
      _adminNameController,
      _adminDisplayNameController,
      _adminEmailController,
      _adminPasswordController,
      _adminPasswordAgainController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 拉取博客信息，未初始化时进入初始化流程。
  ///
  /// 同时驱动服务器连接状态图标的展示。
  Future<void> _refreshBlogInfo() async {
    setState(() => _loadingBlogInfo = true);
    try {
      final info = await ref.read(authApiProvider).blogInfo();
      if (!mounted) return;
      setState(() {
        _blogInfo = info;
        _connected = true;
        _connectError = null;
        _mode = info == null ? _LoginMode.createBlog : _LoginMode.login;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _blogInfo = null;
        _connected = false;
        _connectError = error.message;
        _mode = _LoginMode.login;
        // 连接失败时自动展开服务器管理面板，方便切换或修改地址
        _serverPanelOpen = true;
      });
    } finally {
      if (mounted) setState(() => _loadingBlogInfo = false);
    }
    _maybeAutoBiometricLogin();
  }

  /// 进入登录页后自动拉起一次生物识别登录。
  ///
  /// 仅在服务可用、处于登录模式且已启用生物识别时触发；
  /// 用户取消后本次进入不再重复弹起。
  Future<void> _maybeAutoBiometricLogin() async {
    if (_biometricAutoTried || !mounted) return;
    if (!_connected || _mode != _LoginMode.login) return;
    _biometricAutoTried = true;
    final state = await ref.read(biometricLoginProvider.future);
    if (!mounted || !state.enabled) return;
    await _loginWithBiometric(auto: true);
  }

  /// 使用已保存的账号密码通过生物识别登录。
  Future<void> _loginWithBiometric({bool auto = false}) async {
    if (_biometricRunning || _submitting) return;
    setState(() => _biometricRunning = true);
    try {
      final credential = await ref
          .read(biometricLoginProvider.notifier)
          .authenticateAndRead();
      if (!mounted) return;
      if (credential == null) {
        if (!auto) {
          showGlobalSnack('未通过身份验证，请重试或使用账号密码登录');
        }
        return;
      }
      _usernameController.text = credential.username;
      _passwordController.text = credential.password;
      try {
        await ref.read(sessionProvider.notifier).login(
              credential.username,
              credential.password,
            );
        if (!mounted) return;
        context.go('/dashboard');
      } on ApiException catch (error) {
        if (!mounted) return;
        // 保存的账号密码已失效：清除后回落到手动登录
        await ref.read(biometricLoginProvider.notifier).clearInvalid();
        if (mounted) {
          showGlobalSnack('生物识别登录失败：${error.message}', error: true);
        }
      }
    } finally {
      if (mounted) setState(() => _biometricRunning = false);
    }
  }

  /// 规范化服务器地址（去空白与结尾斜杠）。
  String _normalizeServerUrl(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/') && trimmed.length > 1
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// 连接测试并保存：探测成功才加入服务器列表并设为当前。
  Future<void> _connectAndSave() async {
    final url = _normalizeServerUrl(_serverUrlController.text);
    if (url.isEmpty) {
      setState(() => _probeError = '请输入服务器地址');
      return;
    }
    if (_probing) return;
    setState(() {
      _probing = true;
      _probeError = null;
    });
    final result = await ServerProbe.probe(url);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _probing = false;
        _probeError = result.message;
      });
      return;
    }
    await _applyServer(url);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _serverPanelOpen = false;
      _serverUrlController.clear();
    });
    showSnack(context, result.message, icon: Icons.check_circle_rounded);
  }

  /// 切换到已保存的服务器（先探测，成功才切换）。
  Future<void> _switchServer(String url) async {
    if (_probing || url == ref.read(localStorageProvider).serverUrl) return;
    setState(() {
      _probing = true;
      _probeError = null;
    });
    final result = await ServerProbe.probe(url);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _probing = false;
        _probeError = result.message;
      });
      return;
    }
    await _applyServer(url);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _serverPanelOpen = false;
    });
    showSnack(context, '已切换到 $url', icon: Icons.check_circle_rounded);
  }

  /// 将服务器地址设为当前并保存到历史记录。
  Future<void> _applyServer(String url) async {
    final storage = ref.read(localStorageProvider);
    await storage.setServerUrl(url);
    // 生物识别登录状态按服务器隔离，切换后重新加载
    ref.invalidate(biometricLoginProvider);
    // 去重后置顶到列表首位
    final servers = [
      url,
      ...storage.savedServers.where((item) => item != url),
    ];
    await storage.setSavedServers(servers);
    if (!mounted) return;
    setState(() => _savedServers = servers);
    await _refreshBlogInfo();
  }

  /// 删除已保存的服务器记录（当前使用的除外）。
  Future<void> _deleteServer(String url) async {
    if (url == ref.read(localStorageProvider).serverUrl) return;
    final storage = ref.read(localStorageProvider);
    final servers = storage.savedServers.where((item) => item != url).toList();
    await storage.setSavedServers(servers);
    if (!mounted) return;
    setState(() => _savedServers = servers);
  }

  /// 服务器连接状态说明。
  String get _connectionStatusText {
    if (_loadingBlogInfo) return '正在连接…';
    if (_connected) return '已连接，Nola 服务可用';
    if (_connectError != null) return _connectError!;
    return '未连接';
  }

  /// 提交登录。
  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    try {
      await ref.read(sessionProvider.notifier).login(username, password);
      if (!mounted) return;
      // 记录待处理的启用请求，进入控制台后由 Shell 弹出提示
      ref
          .read(biometricEnrollmentOfferProvider.notifier)
          .offer(username, password);
      context.go('/dashboard');
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 提交初始化博客。
  Future<void> _submitCreateBlog() async {
    if (!_blogFormKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final subtitle = _blogSubtitleController.text.trim();
      await ref.read(authApiProvider).initBlog(
            title: _blogTitleController.text.trim(),
            subtitle: subtitle.isEmpty ? null : subtitle,
          );
      if (!mounted) return;
      setState(() => _mode = _LoginMode.createAdmin);
      showGlobalSnack( '博客创建成功，请创建管理员账号');
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 提交初始化管理员。
  Future<void> _submitCreateAdmin() async {
    if (!_adminFormKey.currentState!.validate() || _submitting) return;
    if (_adminPasswordController.text != _adminPasswordAgainController.text) {
      showGlobalSnack( '两次输入的密码不一致', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authApiProvider).initAdmin(
            username: _adminNameController.text.trim(),
            displayName: _adminDisplayNameController.text.trim(),
            email: _adminEmailController.text.trim(),
            password: _adminPasswordController.text,
          );
      if (!mounted) return;
      setState(() {
        _usernameController.text = _adminNameController.text.trim();
        _mode = _LoginMode.login;
      });
      showGlobalSnack( '管理员创建成功，请登录');
    } on ApiException catch (error) {
      if (mounted) showGlobalSnack( error.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 品牌 Logo
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/nola_logo.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nola 控制台',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '移动端博客管理',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_loadingBlogInfo)
                    // 外层 Column 为 stretch 布局，需用 Center 提供
                    // 松约束，避免进度条被水平拉伸为椭圆
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    _buildForm(),
                  const SizedBox(height: 16),
                  _buildServerCard(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 当前模式对应的表单。
  Widget _buildForm() {
    switch (_mode) {
      case _LoginMode.login:
        return _buildLoginForm();
      case _LoginMode.createBlog:
        return _buildCreateBlogForm();
      case _LoginMode.createAdmin:
        return _buildCreateAdminForm();
    }
  }

  /// 登录表单。
  Widget _buildLoginForm() {
    final biometric = ref.watch(biometricLoginProvider).value;
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _blogInfo?.title ?? '欢迎回来',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_blogInfo?.subtitle?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              _blogInfo!.subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入用户名' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            onFieldSubmitted: (_) => _submitLogin(),
            validator: (value) =>
                value == null || value.isEmpty ? '请输入密码' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submitLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          if (biometric != null && biometric.enabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting || _biometricRunning
                  ? null
                  : () => _loginWithBiometric(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: _biometricRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_biometricIcon(biometric)),
              label: Text(biometric.loginLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// 生物识别登录按钮图标。
  IconData _biometricIcon(BiometricLoginState state) {
    if (state.usesFace) return Icons.face_retouching_natural;
    if (state.usesFingerprint) return Icons.fingerprint;
    return Icons.password_rounded;
  }

  /// 初始化博客表单。
  Widget _buildCreateBlogForm() {
    return Form(
      key: _blogFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '初始化博客',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '检测到博客尚未创建，请先完成博客初始化',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _blogTitleController,
            decoration: const InputDecoration(
              labelText: '站点标题',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入站点标题' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _blogSubtitleController,
            decoration: const InputDecoration(
              labelText: '站点副标题（可选）',
              prefixIcon: Icon(Icons.subtitles_outlined),
            ),
            onFieldSubmitted: (_) => _submitCreateBlog(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submitCreateBlog,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建博客'),
          ),
        ],
      ),
    );
  }

  /// 初始化管理员表单。
  Widget _buildCreateAdminForm() {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '创建管理员',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _adminNameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入用户名' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adminDisplayNameController,
            decoration: const InputDecoration(
              labelText: '昵称',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入昵称' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '请输入邮箱';
              if (!isValidEmail(value.trim())) return '邮箱格式不正确';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adminPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.isEmpty ? '请输入密码' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adminPasswordAgainController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '确认密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onFieldSubmitted: (_) => _submitCreateAdmin(),
            validator: (value) =>
                value == null || value.isEmpty ? '请再次输入密码' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submitCreateAdmin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建管理员'),
          ),
        ],
      ),
    );
  }

  /// 服务器设置卡片：展示当前连接状态，输入框在连接成功后隐藏。
  Widget _buildServerCard(ThemeData theme) {
    final activeServer = ref.watch(localStorageProvider).serverUrl;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: _buildStatusIcon(theme),
            title: Text('服务器设置', style: theme.textTheme.bodyMedium),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeServer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    _connectionStatusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _connected
                          ? theme.colorScheme.primary
                          : (_connectError != null
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ),
            // 切换按钮：展开 / 收起服务器管理面板
            trailing: IconButton.filledTonal(
              tooltip: _serverPanelOpen ? '收起面板' : '切换服务器',
              icon: Icon(
                _serverPanelOpen
                    ? Icons.expand_less_rounded
                    : Icons.swap_horiz_rounded,
              ),
              onPressed: () =>
                  setState(() => _serverPanelOpen = !_serverPanelOpen),
            ),
          ),
          if (_serverPanelOpen) _buildServerPanel(theme),
        ],
      ),
    );
  }

  /// 连接状态图标。
  Widget _buildStatusIcon(ThemeData theme) {
    if (_loadingBlogInfo || _probing) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (_connected) {
      return Icon(
        Icons.check_circle_rounded,
        color: theme.colorScheme.primary,
        size: 28,
      );
    }
    return Icon(
      Icons.cloud_off_rounded,
      color: theme.colorScheme.outline,
      size: 28,
    );
  }

  /// 服务器管理面板：已保存列表 + 新增连接。
  Widget _buildServerPanel(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 已保存的服务器列表
          for (final url in _savedServers)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                url == ref.watch(localStorageProvider).serverUrl
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: url == ref.watch(localStorageProvider).serverUrl
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: url == ref.watch(localStorageProvider).serverUrl
                  ? Text(
                      '当前',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : IconButton(
                      tooltip: '删除记录',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _deleteServer(url),
                    ),
              onTap: () => _switchServer(url),
            ),
          const Divider(height: 20),
          // 新增服务器
          Text('添加服务器', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _serverUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: kDefaultServerUrl,
                  ),
                  onFieldSubmitted: (_) => _connectAndSave(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _probing ? null : _connectAndSave,
                icon: const Icon(Icons.wifi_rounded, size: 18),
                label: const Text('测试连接'),
              ),
            ],
          ),
          if (_probeError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _probeError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '将检测目标是否为可用的 Nola 服务，成功后保存到列表。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
