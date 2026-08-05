import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

const inboxForegroundPollInterval = Duration(seconds: 30);
const inboxForegroundToastDuration = Duration(seconds: 4);

/// Pure helper: unread rows whose ids are not in [seenIds] (newest first).
@visibleForTesting
List<InboxNotification> newUnreadNotifications({
  required List<InboxNotification> items,
  required Set<String> seenIds,
}) {
  return [
    for (final item in items)
      if (item.isUnread && !seenIds.contains(item.id)) item,
  ];
}

/// Polls inbox while resumed + authenticated and shows a top toast for new rows.
class InboxForegroundHost extends ConsumerStatefulWidget {
  const InboxForegroundHost({super.key});

  @override
  ConsumerState<InboxForegroundHost> createState() =>
      _InboxForegroundHostState();
}

class _InboxForegroundHostState extends ConsumerState<InboxForegroundHost>
    with WidgetsBindingObserver {
  final Set<String> _seenIds = {};
  var _baselineSeeded = false;
  Timer? _pollTimer;
  Timer? _toastTimer;
  InboxNotification? _toast;
  var _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPollTimer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncPollTimer();
    if (state == AppLifecycleState.resumed &&
        ref.read(sessionProvider).isAuthenticated) {
      unawaited(ref.read(notificationsInboxProvider.notifier).softRefresh());
    }
  }

  void _syncPollTimer() {
    final authed = ref.read(sessionProvider).isAuthenticated;
    final shouldPoll = authed && _lifecycle == AppLifecycleState.resumed;
    if (shouldPoll) {
      _pollTimer ??= Timer.periodic(inboxForegroundPollInterval, (_) {
        if (!mounted) {
          return;
        }
        if (!ref.read(sessionProvider).isAuthenticated) {
          _syncPollTimer();
          return;
        }
        unawaited(ref.read(notificationsInboxProvider.notifier).softRefresh());
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _onInbox(List<InboxNotification> items) {
    if (!_baselineSeeded) {
      _seenIds
        ..clear()
        ..addAll(items.map((e) => e.id));
      _baselineSeeded = true;
      return;
    }

    final fresh = newUnreadNotifications(items: items, seenIds: _seenIds);
    for (final item in items) {
      _seenIds.add(item.id);
    }
    if (fresh.isEmpty) {
      return;
    }

    final path = GoRouterState.of(context).uri.path;
    if (path.endsWith('/inbox') || path.contains('/notifications/inbox')) {
      return;
    }
    _showToast(fresh.first);
  }

  void _showToast(InboxNotification item) {
    _toastTimer?.cancel();
    setState(() => _toast = item);
    unawaited(AppHaptics.selectionClick());
    _toastTimer = Timer(inboxForegroundToastDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _toast = null);
    });
  }

  void _openInbox() {
    _toastTimer?.cancel();
    setState(() => _toast = null);
    unawaited(context.pushNamed(AppRouteNames.settingsNotificationsInbox));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (!next.isAuthenticated) {
        _baselineSeeded = false;
        _seenIds.clear();
        _toastTimer?.cancel();
        if (_toast != null) {
          setState(() => _toast = null);
        }
      }
      _syncPollTimer();
    });

    ref.listen<AsyncValue<List<InboxNotification>>>(
      notificationsInboxProvider,
      (prev, next) {
        final items = next.valueOrNull;
        if (items == null) {
          return;
        }
        _onInbox(items);
      },
    );

    // Keep provider alive while shell is mounted (badge + toast).
    final inboxAsync = ref.watch(notificationsInboxProvider);
    final currentItems = inboxAsync.valueOrNull;
    if (currentItems != null && !_baselineSeeded) {
      _seenIds
        ..clear()
        ..addAll(currentItems.map((e) => e.id));
      _baselineSeeded = true;
    }

    final toast = _toast;
    if (toast == null) {
      return const SizedBox.shrink();
    }

    final top = MediaQuery.paddingOf(context).top + 8;
    final title = SettingsNotificationsInboxScreen.clampText(
      toast.headline,
      SettingsNotificationsInboxScreen.maxNameChars,
    );
    final body = SettingsNotificationsInboxScreen.clampText(
      toast.body,
      SettingsNotificationsInboxScreen.maxBodyChars,
    );

    return Positioned(
      key: const ValueKey('inbox-foreground-toast'),
      top: top,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: AppShadows.settingsTile,
          ),
          child: InkWell(
            onTap: _openInbox,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.settingsRowTitle,
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
