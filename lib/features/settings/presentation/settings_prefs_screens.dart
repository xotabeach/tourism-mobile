import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/notifications/app_push.dart';
import 'package:tourism_mobile/core/notifications/push_sync.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsNotificationsScreen extends ConsumerWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final sessionCtl = ref.read(sessionProvider.notifier);
    final unread = ref.watch(notificationsUnreadCountProvider);
    final appHapticsEnabled = ref.watch(appHapticsEnabledProvider);
    final inboxSubtitle = unread == 0
        ? 'У вас нет новых уведомлений'
        : 'Новых уведомлений: $unread';
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
          subtitle: 'Уведомления из приложения',
          iconAsset: AppIconography.settingsPush,
          value: session.notifyPushEnabled,
          onChanged: (value) {
            unawaited(
              sessionCtl.updateNotificationPrefs(notifyPushEnabled: value),
            );
            // Registers FCM token when Firebase is configured; no-op otherwise.
            unawaited(syncPushRegistration(ref, enabled: value));
            if (!AppPush.isConfigured && value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Системные пуши включатся после настройки Firebase',
                  ),
                ),
              );
            }
          },
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
