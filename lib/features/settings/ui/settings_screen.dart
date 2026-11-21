import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/blog_models.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/app_settings_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/data/auth_api.dart';
import '../../files/data/file_api.dart';
import '../../shell/ui/console_shell.dart';
import '../data/setting_api.dart';
import '../providers/settings_providers.dart';

/// 设置页：博客设置、备案设置与账号管理。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: const ConsoleAppBar(title: '设置'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 账号卡片
          if (session != null) _AccountCard(user: session),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '站点设置',
            children: [
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('博客信息'),
                subtitle: const Text('标题、副标题、Logo 与 Favicon'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBlogInfoSheet(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('备案信息'),
                subtitle: const Text('ICP 备案号与公网安备号'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showIcpSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '应用设置',
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('主题模式'),
                subtitle: Text(_themeModeLabel(
                  ref.watch(appSettingsProvider).themeMode,
                )),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeModeDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题色'),
                subtitle: Text(
                  ref.watch(appSettingsProvider).useCustomSeed
                      ? '自定义'
                      : 'Nola 蓝（默认）',
                ),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: ref.watch(appSettingsProvider).seedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => _showSeedColorDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '账号安全',
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('个人资料'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showProfileSheet(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPasswordSheet(context, ref),
              ),
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 服务器信息
          _SettingsGroup(
            title: '服务器',
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('服务器地址'),
                subtitle: Text(ref.watch(localStorageProvider).serverUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 博客信息设置。
  Future<void> _showBlogInfoSheet(BuildContext context, WidgetRef ref) async {
    final blogInfo = await ref.read(blogInfoProvider.future);
    if (!context.mounted) return;

    final titleController = TextEditingController(text: blogInfo?.title ?? '');
    final subtitleController =
        TextEditingController(text: blogInfo?.subtitle ?? '');
    final logoController = TextEditingController(text: blogInfo?.logo ?? '');
    final faviconController =
        TextEditingController(text: blogInfo?.favicon ?? '');
    var uploadingField = '';

    Future<void> uploadTo(TextEditingController controller, String field) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      // 上传后地址相对服务器，需要完整 URL 供前台使用
      try {
        final item = await ref.read(fileApiProvider).upload(
              fileName: file.name,
              fileBytes: file.bytes!,
            );
        if (item != null) {
          final serverUrl = ref.read(localStorageProvider).serverUrl;
          controller.text = resolveFileUrl(item.url, serverUrl);
        }
      } on ApiException catch (error) {
        if (context.mounted) {
          showGlobalSnack( error.message, error: true);
        }
      }
      uploadingField = field;
    }

    await showFormSheet(
      context,
      title: '博客信息',
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '站点标题'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: subtitleController,
              decoration: const InputDecoration(labelText: '站点副标题'),
            ),
            const SizedBox(height: 12),
            _UploadField(
              label: 'Logo 地址',
              controller: logoController,
              uploading: uploadingField == 'logo',
              onUpload: () => uploadTo(logoController, 'logo'),
            ),
            const SizedBox(height: 12),
            _UploadField(
              label: 'Favicon 地址',
              controller: faviconController,
              uploading: uploadingField == 'favicon',
              onUpload: () => uploadTo(faviconController, 'favicon'),
            ),
          ],
        ),
      ),
      onSave: () async {
        final title = titleController.text.trim();
        if (title.isEmpty) {
          showGlobalSnack( '站点标题不能为空', error: true);
          return false;
        }
        try {
          await ref.read(settingApiProvider).updateBlogInfo(
                title: title,
                subtitle: subtitleController.text.trim().isEmpty
                    ? null
                    : subtitleController.text.trim(),
                logo: logoController.text.trim().isEmpty
                    ? null
                    : logoController.text.trim(),
                favicon: faviconController.text.trim().isEmpty
                    ? null
                    : faviconController.text.trim(),
              );
          ref.invalidate(blogInfoProvider);
          if (context.mounted) showGlobalSnack( '博客信息已保存');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  /// 备案信息设置。
  Future<void> _showIcpSheet(BuildContext context, WidgetRef ref) async {
    final icp = await ref.read(icpProvider.future);
    if (!context.mounted) return;

    final icpController = TextEditingController(text: icp?.icp ?? '');
    final policeController = TextEditingController(text: icp?.police ?? '');

    await showFormSheet(
      context,
      title: '备案信息',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: icpController,
            decoration: const InputDecoration(labelText: 'ICP 备案号'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: policeController,
            decoration: const InputDecoration(labelText: '公网安备号'),
          ),
        ],
      ),
      onSave: () async {
        try {
          await ref.read(settingApiProvider).updateICP(ICPFiling(
                icp: icpController.text.trim().isEmpty
                    ? null
                    : icpController.text.trim(),
                police: policeController.text.trim().isEmpty
                    ? null
                    : policeController.text.trim(),
              ));
          ref.invalidate(icpProvider);
          if (context.mounted) showGlobalSnack( '备案信息已保存');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  /// 个人资料设置。
  Future<void> _showProfileSheet(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;

    final usernameController =
        TextEditingController(text: session.username);
    final displayNameController =
        TextEditingController(text: session.displayName);
    final emailController = TextEditingController(text: session.email);
    final avatarController = TextEditingController(text: session.avatar ?? '');
    final descriptionController =
        TextEditingController(text: session.description ?? '');

    await showFormSheet(
      context,
      title: '个人资料',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: '昵称'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '邮箱'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: avatarController,
            decoration: const InputDecoration(labelText: '头像地址'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '个人描述'),
          ),
        ],
      ),
      onSave: () async {
        final email = emailController.text.trim();
        if (!isValidEmail(email)) {
          showGlobalSnack( '邮箱格式不正确', error: true);
          return false;
        }
        try {
          await ref.read(authApiProvider).updateUserInfo(UserInfoRequest(
                username: usernameController.text.trim(),
                email: email,
                displayName: displayNameController.text.trim(),
                avatar: avatarController.text.trim().isEmpty
                    ? null
                    : avatarController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              ));
          if (context.mounted) showGlobalSnack( '个人资料已保存');
          await ref
              .read(sessionProvider.notifier)
              .refreshUserInfo();
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  /// 修改密码。
  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showFormDialog(
      context,
      title: '修改密码',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密码'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '确认新密码'),
          ),
        ],
      ),
      onSave: () async {
        final password = passwordController.text;
        if (password.isEmpty) {
          showGlobalSnack( '密码不能为空', error: true);
          return false;
        }
        if (password != confirmController.text) {
          showGlobalSnack( '两次输入的密码不一致', error: true);
          return false;
        }
        try {
          await ref.read(authApiProvider).updatePassword(password);
          if (context.mounted) showGlobalSnack( '密码已修改');
          return true;
        } on ApiException catch (error) {
          if (context.mounted) showGlobalSnack( error.message, error: true);
          return false;
        }
      },
    );
  }

  /// 退出登录。
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '退出登录',
      content: '确定退出当前账号吗？',
      danger: true,
      confirmText: '退出',
    );
    if (!confirmed) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  /// 主题模式展示名称。
  static String _themeModeLabel(AppThemeMode mode) => mode.label;

  /// 主题模式选择弹窗。
  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appSettingsProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('主题模式'),
        content: RadioGroup<AppThemeMode>(
          groupValue: ref.read(appSettingsProvider).themeMode,
          onChanged: (value) {
            if (value != null) controller.setThemeMode(value);
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in AppThemeMode.values)
                RadioListTile<AppThemeMode>(
                  title: Text(mode.label),
                  value: mode,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 主题色选择弹窗。
  void _showSeedColorDialog(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appSettingsProvider.notifier);
    final current = ref.read(appSettingsProvider).seedColor;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('主题色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in kPresetSeedColors)
                    InkWell(
                      onTap: () {
                        controller.setSeedColor(color);
                        Navigator.of(dialogContext).pop();
                      },
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: current == color
                              ? Border.all(
                                  width: 3,
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .outline,
                                )
                              : null,
                        ),
                        child: current == color
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '切换后立即生效，主题色将应用于全应用的按钮、高亮等元素。',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.setSeedColor(null);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

/// 账号信息卡片。
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});

  final UserInfo user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final avatar = user.avatar;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage:
                  avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar == null || avatar.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName.characters.first
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.username} · ${user.email}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    '最后登录：${formatDateTime(user.lastLoginDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置分组容器。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const Divider(height: 1),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 带上传按钮的地址输入框。
class _UploadField extends StatelessWidget {
  const _UploadField({
    required this.label,
    required this.controller,
    required this.uploading,
    required this.onUpload,
  });

  final String label;
  final TextEditingController controller;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: uploading ? null : onUpload,
          icon: uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_rounded),
        ),
      ],
    );
  }
}
