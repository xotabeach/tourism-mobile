import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/routes/application/route_reviews_providers.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Server-backed inbox (in-app). System push (FCM) is deferred.
class SettingsNotificationsInboxScreen extends ConsumerWidget {
  const SettingsNotificationsInboxScreen({super.key});

  static const maxBodyChars = 180;
  static const maxNameChars = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsInboxProvider);

    return SettingsScaffold(
      title: 'Мои уведомления:',
      showSave: true,
      onSave: () {
        unawaited(ref.read(notificationsInboxProvider.notifier).markAllRead());
      },
      spaceChildren: false,
      children: [
        const _InboxLifecycleGuard(),
        if (async.valueOrNull?.isNotEmpty ?? false) ...[
          _ClearActions(items: async.valueOrNull!),
          const SizedBox(height: 12),
        ],
        async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          skipError: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: AppListSkeleton(rows: 5),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Не удалось загрузить уведомления',
                style: AppTypography.settingsRowSubtitle,
              ),
              TextButton(
                onPressed: () =>
                    ref.read(notificationsInboxProvider.notifier).refresh(),
                child: const Text('Повторить'),
              ),
            ],
          ),
          data: (items) {
            final unread = items.where((n) => n.isUnread).toList();
            final read = items.where((n) => !n.isUnread).toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'У вас нет новых уведомлений',
                  style: AppTypography.settingsRowSubtitle,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread.isNotEmpty) ...[
                  Text(
                    'Новые уведомления:',
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < unread.length; i++) ...[
                    if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
                    _InboxTile(
                      item: unread[i],
                      onTap: () => _openNotification(context, ref, unread[i]),
                      onDelete: () => _deleteOne(context, ref, unread[i]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const SettingsHairline(),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Прочитанные:',
                  style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (read.isEmpty)
                  const Text(
                    'Пока пусто',
                    style: AppTypography.settingsRowSubtitle,
                  )
                else
                  for (var i = 0; i < read.length; i++) ...[
                    if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
                    _InboxTile(
                      item: read[i],
                      onTap: () => _openNotification(context, ref, read[i]),
                      onDelete: () => _deleteOne(context, ref, read[i]),
                    ),
                  ],
                const SizedBox(height: 120),
              ],
            );
          },
        ),
      ],
    );
  }

  static void _deleteOne(
    BuildContext context,
    WidgetRef ref,
    InboxNotification item,
  ) {
    unawaited(AppHaptics.selectionClick());
    final notifier = ref.read(notificationsInboxProvider.notifier)
      ..queueDelete([item]);
    final messenger = ScaffoldMessenger.of(context);
    final count = notifier.pendingCount;
    final label = count == 1 ? 'Уведомление удалено' : 'Удалено: $count';
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: notificationsUndoWindow,
          content: Semantics(liveRegion: true, child: Text(label)),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: notifier.undoPending,
          ),
        ),
      );
  }

  static Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    InboxNotification item,
  ) async {
    unawaited(AppHaptics.selectionClick());
    unawaited(ref.read(notificationsInboxProvider.notifier).markRead(item.id));
    if (item.targetType == 'route' &&
        item.targetId != null &&
        item.targetId!.isNotEmpty) {
      // Moderation may have just flipped pending → published; drop stale mine.
      ref.invalidate(myRouteReviewsProvider);
      ref.invalidate(routeReviewsProvider(item.targetId!));
      await context.pushNamed(
        AppRouteNames.routeDetails,
        pathParameters: {'id': item.targetId!},
      );
      return;
    }
    if (item.targetType == 'user' &&
        item.targetId != null &&
        item.targetId!.isNotEmpty) {
      await context.pushNamed(
        AppRouteNames.userProfile,
        pathParameters: {'userId': item.targetId!},
      );
      return;
    }
    if (item.kind == InboxNotificationKind.antifraudFlagged ||
        item.kind == InboxNotificationKind.antifraudBlocked ||
        item.kind == InboxNotificationKind.antifraudPointsDecision) {
      // Nothing to open: the notice itself is the whole message.
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title),
          content: Text(item.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      return;
    }
    if (item.kind == InboxNotificationKind.achievementUnlocked ||
        item.targetType == 'achievement') {
      await context.pushNamed(AppRouteNames.achievements);
      return;
    }
    if (item.kind == InboxNotificationKind.supportReply ||
        item.targetType == 'support_ticket') {
      await context.pushNamed(AppRouteNames.settingsChat);
    }
  }

  static String clampText(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) {
      return trimmed;
    }
    return '${trimmed.substring(0, max)}…';
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, this.onTap, this.onDelete});

  final InboxNotification item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = SettingsNotificationsInboxScreen.clampText(
      item.headline,
      SettingsNotificationsInboxScreen.maxNameChars,
    );
    final body = SettingsNotificationsInboxScreen.clampText(
      item.body,
      SettingsNotificationsInboxScreen.maxBodyChars,
    );
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

    final radius = BorderRadius.circular(AppRadii.settingsTile);
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.settingsTile,
      ),
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  onTap!();
                },
          borderRadius: radius,
          child: SizedBox(
            height: SettingsMetrics.rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE5E5EA),
                    child: Text(
                      initial.toUpperCase(),
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowSubtitle,
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      key: ValueKey('inbox-delete-${item.id}'),
                      tooltip: 'Удалить уведомление',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onDelete == null) {
      return tile;
    }
    return Dismissible(
      key: ValueKey('inbox-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete!(),
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D),
          borderRadius: radius,
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
        ),
      ),
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Удалить уведомление'): onDelete!,
        },
        child: tile,
      ),
    );
  }
}

/// Flushes pending deletes when the screen is left and reports failures.
class _InboxLifecycleGuard extends ConsumerStatefulWidget {
  const _InboxLifecycleGuard();

  @override
  ConsumerState<_InboxLifecycleGuard> createState() =>
      _InboxLifecycleGuardState();
}

class _InboxLifecycleGuardState extends ConsumerState<_InboxLifecycleGuard> {
  late final NotificationsInboxController _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(notificationsInboxProvider.notifier);
  }

  @override
  void dispose() {
    unawaited(_notifier.flushPending());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(notificationsDeleteFailedProvider, (prev, next) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить, уведомления возвращены'),
          ),
        );
    });
    return const SizedBox.shrink();
  }
}

class _ClearActions extends ConsumerWidget {
  const _ClearActions({required this.items});

  final List<InboxNotification> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRead = items.any((n) => !n.isUnread);
    return Wrap(
      spacing: 8,
      children: [
        if (hasRead)
          TextButton(
            onPressed: () =>
                _confirm(context, ref, NotificationsClearScope.read),
            child: const Text('Очистить прочитанные'),
          ),
        TextButton(
          onPressed: () => _confirm(context, ref, NotificationsClearScope.all),
          child: const Text('Очистить все'),
        ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    NotificationsClearScope scope,
  ) async {
    final notifier = ref.read(notificationsInboxProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final int count;
    try {
      await notifier.flushPending();
      count = await notifier.previewClear(scope);
    } on NotFoundFailure {
      messenger.showSnackBar(
        const SnackBar(content: Text('Обновите приложение, чтобы очищать')),
      );
      return;
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось выполнить, попробуйте позже')),
      );
      return;
    }
    if (count == 0 || !context.mounted) {
      if (count == 0) {
        messenger.showSnackBar(const SnackBar(content: Text('Нечего очищать')));
      }
      return;
    }
    final what = scope == NotificationsClearScope.read
        ? 'прочитанные уведомления'
        : 'все уведомления';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить $what?'),
        content: Text(
          'Будет удалено: $count. Восстановить их не получится. '
          'Уведомления, пришедшие позже, останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final deleted = await notifier.clearBulk(scope);
      messenger.showSnackBar(SnackBar(content: Text('Удалено: $deleted')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось удалить, попробуйте позже')),
      );
    }
  }
}
