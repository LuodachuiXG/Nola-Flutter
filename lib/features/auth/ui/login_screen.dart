import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/formatters.dart' show isValidEmail;
import '../../../shared/widgets/dialogs.dart';
import '../../../core/models/blog_models.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = ref.read(localStorageProvider).serverUrl;
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
  Future<void> _refreshBlogInfo() async {
    setState(() => _loadingBlogInfo = true);
    try {
      final info = await ref.read(authApiProvider).blogInfo();
      if (!mounted) return;
      setState(() {
        _blogInfo = info;
        _mode = info == null ? _LoginMode.createBlog : _LoginMode.login;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _mode = _LoginMode.login);
      showGlobalSnack( '获取博客信息失败：$error', error: true);
    } finally {
      if (mounted) setState(() => _loadingBlogInfo = false);
    }
  }

  /// 保存服务器地址。
  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      showGlobalSnack( '服务器地址不能为空', error: true);
      return;
    }
    await ref.read(localStorageProvider).setServerUrl(url);
    if (!mounted) return;
    showGlobalSnack( '服务器地址已保存');
    _refreshBlogInfo();
  }

  /// 提交登录。
  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
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
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    )
                  else
                    _buildForm(),
                  const SizedBox(height: 16),
                  _buildServerUrlExpansion(theme),
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
        ],
      ),
    );
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

  /// 服务器地址设置。
  Widget _buildServerUrlExpansion(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          // 顶部与底部留足间距，避免展开内容与标题贴在一起
          childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          leading: const Icon(Icons.dns_outlined),
          title: Text('服务器设置', style: theme.textTheme.bodyMedium),
          subtitle: Text(
            _serverUrlController.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          children: [
            TextFormField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: kDefaultServerUrl,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saveServerUrl,
              child: const Text('保存并连接'),
            ),
          ],
        ),
      ),
    );
  }
}
