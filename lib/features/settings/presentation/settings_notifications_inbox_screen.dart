import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/notifications/notification_target.dart';
import 'package:tourism_mobile/features/routes/application/route_reviews_providers.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

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
            child: AppListSkeleton(
              rows: 5,
              rowHeight: SettingsMetrics.rowHeight,
              tiles: true,
              roundLeading: true,
              gap: SettingsMetrics.rowGap,
              padding: EdgeInsets.zero,
            ),
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
          data: (visible) {
            final notifier = ref.read(notificationsInboxProvider.notifier);
            // A deleted row stays in its place as «Удалить уведомление?»
            // until its undo window ends (DESIGN-8).
            final pendingIds = notifier.pendingIds;
            final items = [...visible, ...notifier.pendingItems]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final unread = items.where((n) => n.isUnread).toList();
            final read = items.where((n) => !n.isUnread).toList();
            Widget row(InboxNotification item) => pendingIds.contains(item.id)
                ? _PendingDeleteTile(
                    key: ValueKey('inbox-pending-${item.id}'),
                    flushAt: notifier.flushAt,
                    onUndo: () => notifier.undoOne(item.id),
                  )
                : _InboxTile(
                    item: item,
                    onTap: () => _openNotification(context, ref, item),
                    onDelete: () => _deleteOne(ref, item),
                  );
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
                    row(unread[i]),
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
                    row(read[i]),
                  ],
                const SizedBox(height: 120),
              ],
            );
          },
        ),
      ],
    );
  }

  static void _deleteOne(WidgetRef ref, InboxNotification item) {
    unawaited(AppHaptics.selectionClick());
    ref.read(notificationsInboxProvider.notifier).queueDelete([item]);
  }

  static Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    InboxNotification item,
  ) async {
    unawaited(AppHaptics.selectionClick());
    unawaited(ref.read(notificationsInboxProvider.notifier).markRead(item.id));
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
    final targetId = item.targetId;
    if (item.targetType == 'route' && targetId != null && targetId.isNotEmpty) {
      // Moderation may have just flipped pending → published; drop stale mine.
      ref.invalidate(myRouteReviewsProvider);
      ref.invalidate(routeReviewsProvider(targetId));
    }
    if (!context.mounted) return;
    // FRONTEND-74: the same way as a push, right to the comment or review.
    openNotificationTarget(
      GoRouter.of(context),
      targetType: switch (item.kind) {
        InboxNotificationKind.achievementUnlocked => 'achievement',
        InboxNotificationKind.supportReply => 'support_ticket',
        _ => item.targetType,
      },
      targetId: targetId,
      anchorId: item.anchorId,
    );
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
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 26,
                        color: AppColors.primaryInk,
                      ),
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
    return _SwipeToDelete(
      key: ValueKey('inbox-${item.id}'),
      radius: radius,
      onDelete: onDelete!,
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Удалить уведомление'): onDelete!,
        },
        child: tile,
      ),
    );
  }
}

/// Swipe left to delete. The red plate is not a full-size background under
/// the card (its corners showed around the card's rounded corners and read
/// as «sticking out»): it grows from the right edge exactly as far as the
/// card has moved, with a small gap and its own rounding, and is invisible
/// until the swipe starts.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.radius,
    required this.onDelete,
    required this.child,
    super.key,
  });

  final BorderRadius radius;
  final VoidCallback onDelete;
  final Widget child;

  // Sampled from the DESIGN-8 mockup.
  static const deleteRed = Color(0xFFFF383C);
  static const gap = 8.0;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${widget.key}'),
      direction: DismissDirection.endToStart,
      onUpdate: (details) => _progress.value = details.progress,
      onDismissed: (_) => widget.onDelete(),
      background: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, _) {
            final width = progress * constraints.maxWidth - _SwipeToDelete.gap;
            if (width <= 0) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                key: const ValueKey('inbox-delete-plate'),
                width: width,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _SwipeToDelete.deleteRed,
                    borderRadius: widget.radius,
                  ),
                  // The bin sits in the middle of the plate, as on the
                  // mockup of a card swiped all the way.
                  child: const ClipRect(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      child: widget.child,
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
    // Leaving sends the pending deletes: they are not coming back.
    unawaited(_notifier.flushPending());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(notificationsDeleteFailedProvider, (prev, next) {
      showAppNotice(
        context,
        'Не удалось удалить, уведомления возвращены',
        kind: AppNoticeKind.error,
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
      spacing: 12,
      runSpacing: 8,
      children: [
        if (hasRead)
          _ClearChip(
            label: 'Очистить прочитанные',
            onPressed: () =>
                _confirm(context, ref, NotificationsClearScope.read),
          ),
        _ClearChip(
          label: 'Очистить все',
          onPressed: () => _confirm(context, ref, NotificationsClearScope.all),
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
    final int count;
    try {
      await notifier.flushPending();
      count = await notifier.previewClear(scope);
    } on NotFoundFailure {
      if (context.mounted) {
        showAppNotice(
          context,
          'Обновите приложение, чтобы очищать',
          kind: AppNoticeKind.error,
        );
      }
      return;
    } on Object {
      if (context.mounted) {
        showAppNotice(
          context,
          'Не удалось выполнить, попробуйте позже',
          kind: AppNoticeKind.error,
        );
      }
      return;
    }
    if (count == 0 || !context.mounted) {
      if (count == 0) {
        if (context.mounted) {
          showAppNotice(context, 'Нечего очищать');
        }
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ClearConfirmDialog(
        title: scope == NotificationsClearScope.read
            ? 'Удалить прочитанные уведомления?'
            : 'Удалить все уведомления?',
        count: count,
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final deleted = await notifier.clearBulk(scope);
      if (context.mounted) {
        showAppNotice(
          context,
          'Удалено: $deleted',
          kind: AppNoticeKind.success,
        );
      }
    } on Object {
      if (context.mounted) {
        showAppNotice(
          context,
          'Не удалось удалить, попробуйте позже',
          kind: AppNoticeKind.error,
        );
      }
    }
  }
}

/// Grey capsule above the list (DESIGN-8): quieter than the screen's own
/// «Сохранить», since both clear actions are destructive.
class _ClearChip extends StatelessWidget {
  const _ClearChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFEDEDED),
        foregroundColor: AppColors.primaryInk,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Text(label),
    );
  }
}

/// A deleted card waiting out its undo window, in the card's own place
/// (DESIGN-8). The cross brings the notification back.
class _PendingDeleteTile extends StatefulWidget {
  const _PendingDeleteTile({
    required this.flushAt,
    required this.onUndo,
    super.key,
  });

  final DateTime? flushAt;
  final VoidCallback onUndo;

  static const red = Color(0xFFFF383C);
  static const plate = Color(0xFFF8D7D8);

  @override
  State<_PendingDeleteTile> createState() => _PendingDeleteTileState();
}

class _PendingDeleteTileState extends State<_PendingDeleteTile> {
  Timer? _tick;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(_PendingDeleteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another swipe moved the shared deadline.
    if (oldWidget.flushAt != widget.flushAt) _restart();
  }

  /// Counts down by its own ticks from the deadline it was given, so the
  /// figure steps once a second whatever the frame rate.
  void _restart() {
    _tick?.cancel();
    final at = widget.flushAt;
    final left = at == null
        ? notificationsUndoWindow.inMilliseconds
        : at.difference(DateTime.now()).inMilliseconds;
    _secondsLeft = (left / 1000).ceil().clamp(
      1,
      notificationsUndoWindow.inSeconds,
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft <= 1) return;
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.settingsTile);
    return Container(
      height: SettingsMetrics.rowHeight,
      decoration: BoxDecoration(
        color: _PendingDeleteTile.plate,
        borderRadius: radius,
      ),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Удалить уведомление?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _PendingDeleteTile.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Автоматическое удаление через $_secondsLeftс',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    color: _PendingDeleteTile.red.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Не удалять',
            constraints: const BoxConstraints.tightFor(width: 56, height: 56),
            onPressed: widget.onUndo,
            icon: const Icon(
              Icons.close_rounded,
              size: 26,
              color: _PendingDeleteTile.red,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Удалить прочитанные уведомления?» with the siren (DESIGN-8). True only
/// for «Всё равно удалить».
class _ClearConfirmDialog extends StatelessWidget {
  const _ClearConfirmDialog({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Image.asset(
                    AppIconography.inboxClearSiren,
                    width: 36,
                    height: 36,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
            const SizedBox(height: 14),
            Text(
              'Будет удалено: $count. Восстановить их не получится. '
              'Уведомления, пришедшие позже, останутся.',
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 15,
                height: 1.35,
                color: AppColors.secondaryInk,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF212121),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Всё равно удалить'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryInk,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Отменить'),
            ),
          ],
        ),
      ),
    );
  }
}
