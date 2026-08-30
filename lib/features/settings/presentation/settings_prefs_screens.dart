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
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/data/offline_route_store.dart';
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
    final downloaded = ref.watch(offlineRoutesProvider);
    final downloadedItems = downloaded.valueOrNull ?? const [];
    return SettingsScaffold(
      title: 'Оффлайн маршруты:',
      subtitle: 'Сохраняйте маршрут и его остановки, чтобы открыть их без сети',
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
        SettingsNavTile(
          title: 'Скачанные маршруты',
          subtitle: downloaded.when(
            loading: () => 'Проверяем сохранённые маршруты…',
            error: (_, _) => 'Не удалось прочитать локальное хранилище',
            data: (items) => items.isEmpty
                ? 'Пока нет маршрутов без сети'
                : '${items.length} ${_routeWord(items.length)} доступно без сети',
          ),
          icon: Icons.download_done_rounded,
          onTap: downloadedItems.isEmpty
              ? null
              : () => _showDownloadedSheet(context, ref, downloadedItems),
          trailing: SettingsCircleIconButton(
            icon: Icons.delete_sweep_outlined,
            onTap: downloadedItems.isEmpty
                ? () {}
                : () => _clearDownloaded(context, ref),
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

  Future<void> _clearDownloaded(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить скачанные маршруты?'),
        content: const Text(
          'Сами маршруты в аккаунте останутся. Удалятся только локальные копии.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await clearDownloadedRoutes(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скачанные маршруты удалены')),
      );
    }
  }

  void _showDownloadedSheet(
    BuildContext context,
    WidgetRef ref,
    List<OfflineRouteRecord> items,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_rounded),
                  title: Text(item.route.name),
                  subtitle: Text(
                    '${item.route.stops.length} остановок · '
                    '${_downloadDate(item.downloadedAt)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Удалить скачанную копию',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await removeDownloadedRoute(ref, item.id);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      context.pushNamed(
                        AppRouteNames.routeDetails,
                        pathParameters: {'id': item.id},
                        extra: item.route,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _routeWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'маршрутов';
    if (mod10 == 1) return 'маршрут';
    if (mod10 >= 2 && mod10 <= 4) return 'маршрута';
    return 'маршрутов';
  }

  static String _downloadDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return 'скачан $day.$month.${value.year}';
  }
}
