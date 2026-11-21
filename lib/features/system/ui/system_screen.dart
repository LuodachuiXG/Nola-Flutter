import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/system_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../shell/ui/console_shell.dart';
import '../data/system_api.dart';
import '../providers/system_providers.dart';

/// 系统页：操作记录与访问日志。
class SystemScreen extends ConsumerStatefulWidget {
  const SystemScreen({super.key});

  @override
  ConsumerState<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends ConsumerState<SystemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: ConsoleAppBar(
          title: '系统',
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight * 0.8),
            child: TabBar(
              tabs: [
                Tab(text: '操作记录'),
                Tab(text: '访问日志'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _OperationTab(),
            _AccessLogTab(),
          ],
        ),
      ),
    );
  }
}

/// 操作记录标签页。
class _OperationTab extends ConsumerWidget {
  const _OperationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(operationListProvider);
    final notifier = ref.read(operationListProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                notifier.sort == CommentSort.createTimeAsc ? '时间升序' : '时间降序',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '清理操作记录',
                    content: '删除 30 天以前的全部操作记录，确定继续吗？',
                    danger: true,
                    confirmText: '清理',
                  );
                  if (!confirmed) return;
                  try {
                    final before = DateTime.now()
                        .subtract(const Duration(days: 30))
                        .millisecondsSinceEpoch;
                    await ref
                        .read(systemApiProvider)
                        .deleteOperationsBefore(before);
                    if (context.mounted) showGlobalSnack( '已清理');
                    await notifier.refresh();
                  } on ApiException catch (error) {
                    if (context.mounted) {
                      showGlobalSnack( error.message, error: true);
                    }
                  }
                },
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('清理 30 天前'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '清空操作记录',
                    content: '将删除全部操作记录，无法恢复，确定继续吗？',
                    danger: true,
                    confirmText: '清空',
                  );
                  if (!confirmed) return;
                  try {
                    await ref.read(systemApiProvider).deleteAllOperations();
                    if (context.mounted) showGlobalSnack( '已清空');
                    await notifier.refresh();
                  } on ApiException catch (error) {
                    if (context.mounted) {
                      showGlobalSnack( error.message, error: true);
                    }
                  }
                },
                child: Text(
                  '清空',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedListView<Operation>(
            value: listState,
            emptyIcon: Icons.history_outlined,
            noItemsMessage: '暂无操作记录',
            onRefresh: () async {
              try {
                await notifier.refresh();
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            onLoadMore: () => notifier.loadMore(),
            itemBuilder: (context, operation) =>
                _OperationTile(operation: operation),
          ),
        ),
      ],
    );
  }
}

/// 操作记录列表项。
class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighRisk = operation.operationType == OperationType.highRisk;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isHighRisk
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
          child: Icon(
            isHighRisk ? Icons.warning_amber_rounded : Icons.touch_app_outlined,
            size: 20,
            color: isHighRisk
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          operation.operationDesc ?? '未知操作',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${operation.username} · ${formatDateTime(operation.createTime)}'
          '${isHighRisk ? ' · 高风险' : ''}',
        ),
      ),
    );
  }
}

/// 访问日志标签页。
class _AccessLogTab extends ConsumerWidget {
  const _AccessLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(accessLogListProvider);
    final notifier = ref.read(accessLogListProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '清理访问日志',
                    content: '删除 30 天以前的全部访问日志，确定继续吗？',
                    danger: true,
                    confirmText: '清理',
                  );
                  if (!confirmed) return;
                  try {
                    final before = DateTime.now()
                        .subtract(const Duration(days: 30))
                        .millisecondsSinceEpoch;
                    await ref
                        .read(systemApiProvider)
                        .deleteAccessLogsBefore(before);
                    if (context.mounted) showGlobalSnack( '已清理');
                    await notifier.refresh();
                  } on ApiException catch (error) {
                    if (context.mounted) {
                      showGlobalSnack( error.message, error: true);
                    }
                  }
                },
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('清理 30 天前'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '清空访问日志',
                    content: '将删除全部访问日志，无法恢复，确定继续吗？',
                    danger: true,
                    confirmText: '清空',
                  );
                  if (!confirmed) return;
                  try {
                    await ref.read(systemApiProvider).deleteAllAccessLogs();
                    if (context.mounted) showGlobalSnack( '已清空');
                    await notifier.refresh();
                  } on ApiException catch (error) {
                    if (context.mounted) {
                      showGlobalSnack( error.message, error: true);
                    }
                  }
                },
                child: Text(
                  '清空',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedListView<AccessLog>(
            value: listState,
            emptyIcon: Icons.travel_explore_outlined,
            noItemsMessage: '暂无访问日志',
            onRefresh: () async {
              try {
                await notifier.refresh();
              } on ApiException catch (error) {
                if (context.mounted) {
                  showGlobalSnack( error.message, error: true);
                }
              }
            },
            onLoadMore: () => notifier.loadMore(),
            itemBuilder: (context, log) => _AccessLogTile(log: log),
          ),
        ),
      ],
    );
  }
}

/// 访问日志列表项。
class _AccessLogTile extends StatelessWidget {
  const _AccessLogTile({required this.log});

  final AccessLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(
          _typeIcon(log.type),
          color: theme.colorScheme.primary,
        ),
        title: Text(
          log.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        subtitle: Text(
          '${log.ip} · ${formatDateTime(log.accessTime)}'
          '${log.message != null ? ' · ${log.message}' : ''}',
        ),
      ),
    );
  }

  IconData _typeIcon(AccessLogType type) {
    switch (type) {
      case AccessLogType.uri:
        return Icons.link_outlined;
      case AccessLogType.blog:
        return Icons.home_outlined;
      case AccessLogType.post:
        return Icons.article_outlined;
    }
  }
}
