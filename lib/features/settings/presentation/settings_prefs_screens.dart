import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/notifications/push_permission.dart';
import 'package:tourism_mobile/core/notifications/push_sync.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen>
    with WidgetsBindingObserver {
  AuthorizationStatus? _osStatus;
  var _pushBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshOsStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _refreshOsStatus() async {
    final status = await AppPush.authorizationStatus();
    if (!mounted) {
      return;
    }
    setState(() => _osStatus = status);
  }

  Future<void> _onResumed() async {
    await _refreshOsStatus();
    if (!mounted) {
      return;
    }
    final session = ref.read(sessionProvider);
    final enabled = effectivePushEnabled(
      preferEnabled: session.notifyPushEnabled,
      osStatus: _osStatus,
      firebaseConfigured: AppPush.isConfigured,
    );
    if (enabled) {
      unawaited(syncPushRegistration(ref, enabled: true));
    }
  }

  Future<void> _promptOpenSystemSettings() async {
    if (!mounted) {
      return;
    }
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Разрешите уведомления'),
        content: const Text(
          'Чтобы показывать системные пуши, включите уведомления '
          'для CrimeaTrip в настройках телефона.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Не сейчас'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
    if (open == true) {
      await AppPush.openSystemNotificationSettings();
    }
  }

  Future<void> _onPushChanged(bool value) async {
    if (_pushBusy) {
      return;
    }
    final sessionCtl = ref.read(sessionProvider.notifier);
    setState(() => _pushBusy = true);
    try {
      if (!value) {
        await sessionCtl.updateNotificationPrefs(notifyPushEnabled: false);
        await syncPushRegistration(ref, enabled: false);
        await _refreshOsStatus();
        return;
      }

      if (!AppPush.isConfigured) {
        await sessionCtl.updateNotificationPrefs(notifyPushEnabled: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Системные пуши включатся после настройки Firebase',
              ),
            ),
          );
        }
        return;
      }

      if (_osStatus == AuthorizationStatus.denied) {
        await _promptOpenSystemSettings();
        await _refreshOsStatus();
        return;
      }

      final ok = await syncPushRegistration(ref, enabled: true);
      await _refreshOsStatus();
      if (!mounted) {
        return;
      }
      if (ok) {
        await sessionCtl.updateNotificationPrefs(notifyPushEnabled: true);
        return;
      }
      await sessionCtl.updateNotificationPrefs(notifyPushEnabled: false);
      await _promptOpenSystemSettings();
    } finally {
      if (mounted) {
        setState(() => _pushBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final sessionCtl = ref.read(sessionProvider.notifier);
    final unread = ref.watch(notificationsUnreadCountProvider);
    final appHapticsEnabled = ref.watch(appHapticsEnabledProvider);
    final inboxSubtitle = unread == 0
        ? 'У вас нет новых уведомлений'
        : 'Новых уведомлений: $unread';
    final pushOn = effectivePushEnabled(
      preferEnabled: session.notifyPushEnabled,
      osStatus: _osStatus,
      firebaseConfigured: AppPush.isConfigured,
    );
    final pushSubtitle = pushToggleSubtitle(
      preferEnabled: session.notifyPushEnabled,
      osStatus: _osStatus,
      firebaseConfigured: AppPush.isConfigured,
    );
    return SettingsScaffold(
      title: 'Настройки уведомлений:',
      showSave: true,
      children: [
        SettingsNavTile(
          title: 'Уведомления',
          subtitle: inboxSubtitle,
          iconAsset: AppIconography.settingsNotifications,
          onTap: () =>
              context.pushNamed(AppRouteNames.settingsNotificationsInbox),
        ),
        SettingsToggleTile(
          title: 'Пуш-уведомления',
          subtitle: pushSubtitle,
          iconAsset: AppIconography.settingsPush,
          value: pushOn,
          onChanged: _pushBusy
              ? (_) {}
              : (value) => unawaited(_onPushChanged(value)),
        ),
        SettingsToggleTile(
          title: 'СМС',
          subtitle: 'Для оповещения без интернета',
          iconAsset: AppIconography.settingsSms,
          value: session.notifySmsEnabled,
          onChanged: (value) {
            unawaited(
              sessionCtl.updateNotificationPrefs(notifySmsEnabled: value),
            );
          },
        ),
        SettingsToggleTile(
          title: 'Звуки и вибрация',
          subtitle: 'При приближении к точке',
          iconAsset: AppIconography.settingsVibro,
          value: session.notifyHapticsEnabled,
          onChanged: (value) {
            unawaited(
              sessionCtl.updateNotificationPrefs(notifyHapticsEnabled: value),
            );
          },
        ),
        SettingsToggleTile(
          title: 'Вибрация в приложении',
          subtitle: 'При нажатиях и жестах',
          iconAsset: AppIconography.settingsVibro,
          value: appHapticsEnabled,
          onChanged: (value) {
            unawaited(
              ref.read(appHapticsEnabledProvider.notifier).setEnabled(value),
            );
          },
        ),
      ],
    );
  }
}

class SettingsOfflineScreen extends ConsumerWidget {
  const SettingsOfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsPreferencesProvider);
    final controller = ref.read(settingsPreferencesProvider.notifier);
    return SettingsScaffold(
      title: 'Оффлайн маршруты:',
      showSave: true,
      children: [
        SettingsToggleTile(
          title: 'Автоматическое скачивание',
          subtitle: 'При добавлении в избранное',
          iconAsset: AppIconography.settingsAutoDownload,
          value: prefs.autoDownloadFavorites,
          onChanged: controller.setAutoDownload,
        ),
        SettingsToggleTile(
          title: 'Спрашивать разрешение',
          subtitle: 'Перед каждым скачиванием',
          iconAsset: AppIconography.settingsAskDownload,
          value: prefs.askBeforeDownload,
          onChanged: controller.setAskBeforeDownload,
        ),
        SettingsNavTile(
          title: 'Кэш приложения',
          subtitle: prefs.cacheSizeLabel,
          iconAsset: AppIconography.settingsOffline,
          onTap: () => _clearCache(context, ref, controller),
          trailing: SettingsCircleIconButton(
            icon: Icons.delete_outline_rounded,
            onTap: () => _clearCache(context, ref, controller),
            background: SettingsColors.circleButton,
            size: 40,
            iconSize: 18,
          ),
        ),
      ],
    );
  }

  void _clearCache(
    BuildContext context,
    WidgetRef ref,
    SettingsController controller,
  ) {
    softRefreshAppData(ref);
    controller.clearCacheLabel();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Кеш API очищен')));
  }
}
