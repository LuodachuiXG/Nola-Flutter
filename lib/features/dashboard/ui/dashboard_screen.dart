import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/blog_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../shell/ui/console_shell.dart';
import '../providers/dashboard_providers.dart';

/// 博客概览页。
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);

    return Scaffold(
      appBar: ConsoleAppBar(
        title: '概览',
        actions: const [_OnlineCountChip()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(overviewProvider.future),
        child: AsyncValueWidget<Overview>(
          value: overview,
          builder: (context, data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildTotalVisitCard(context, data),
              const SizedBox(height: 16),
              _buildStatGrid(context, data.count),
              const SizedBox(height: 16),
              _buildHotTags(context, data),
              const SizedBox(height: 16),
              _buildHotCategories(context, data),
              const SizedBox(height: 16),
              _buildMostViewedPost(context, data),
              const SizedBox(height: 16),
              _buildMetaCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

  /// 总浏览量卡片。
  Widget _buildTotalVisitCard(BuildContext context, Overview data) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.visibility_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文章总浏览量',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.postVisitCount}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 数量统计网格。
  Widget _buildStatGrid(BuildContext context, OverviewCount count) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : 2;
    final items = [
      (label: '文章', value: count.post, icon: Icons.article_rounded, path: '/posts'),
      (label: '标签', value: count.tag, icon: Icons.sell_rounded, path: '/tags'),
      (label: '分类', value: count.category, icon: Icons.category_rounded, path: '/categories'),
      (label: '评论', value: count.comment, icon: Icons.mode_comment_rounded, path: '/comments'),
      (label: '日记', value: count.diary, icon: Icons.edit_note_rounded, path: '/diaries'),
      (label: '附件', value: count.file, icon: Icons.folder_rounded, path: '/files'),
      (label: '友链', value: count.link, icon: Icons.link_rounded, path: '/links'),
      (label: '菜单', value: count.menu, icon: Icons.menu_open_rounded, path: '/menus'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: columns == 4 ? 2.2 : 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return StatCard(
          label: item.label,
          value: '${item.value}',
          icon: item.icon,
          onTap: () => context.push(item.path),
        );
      },
    );
  }

  /// 热门标签。
  Widget _buildHotTags(BuildContext context, Overview data) {
    if (data.tags.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: '热门标签',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in data.tags)
            Chip(
              label: Text('${tag.displayName} (${tag.postCount ?? 0})'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /// 热门分类。
  Widget _buildHotCategories(BuildContext context, Overview data) {
    if (data.categories.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: '热门分类',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in data.categories)
            Chip(
              label:
                  Text('${category.displayName} (${category.postCount ?? 0})'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /// 浏览量最高的文章。
  Widget _buildMostViewedPost(BuildContext context, Overview data) {
    final post = data.mostViewedPost;
    if (post == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return _SectionCard(
      title: '浏览量最高',
      child: InkWell(
        onTap: () => context.push('/posts'),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '浏览 ${post.visit} · ${formatDateTime(post.createTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  /// 博客元信息。
  Widget _buildMetaCard(BuildContext context, Overview data) {
    return _SectionCard(
      title: '博客信息',
      child: Column(
        children: [
          _MetaRow(label: '建站时间', value: formatDateTime(data.createDate)),
          _MetaRow(label: '最后登录', value: formatDateTime(data.lastLoginDate)),
          if (data.lastOperation != null)
            _MetaRow(label: '最近操作', value: data.lastOperation!),
        ],
      ),
    );
  }
}

/// 实时在线人数徽标。
class _OnlineCountChip extends ConsumerWidget {
  const _OnlineCountChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(onlineCountProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: count.when(
        data: (value) => Tooltip(
          message: '当前在线人数',
          child: Chip(
            avatar: Icon(
              Icons.circle,
              size: 10,
              color: theme.colorScheme.primary,
            ),
            label: Text('$value 人在线'),
            visualDensity: VisualDensity.compact,
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// 分区卡片。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 元信息行。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
