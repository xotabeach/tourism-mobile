import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
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
          showAppNotice(
            context,
            'Системные пуши включатся после настройки Firebase',
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
    showAppNotice(context, 'Кеш API очищен');
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
      showAppNotice(context, 'Скачанные маршруты удалены');
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
        // Белая шторка со скруглённой шапкой — как на макете; тема давала
        // сиреневатую подложку, из-за неё голубые плашки терялись.
        backgroundColor: AppColors.elevatedSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // A shrink-wrapped sheet collapsed to a couple of unreadable rows.
        // Give it a real, resizable height instead.
        isScrollControlled: true,
        builder: (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) => _DownloadedRoutesSheet(
            initialItems: items,
            scrollController: scrollController,
            ref: ref,
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

/// Downloaded-routes list with per-route removal.
///
/// Keeps its own copy of the list so removing one route updates the sheet in
/// place — the previous version popped the whole sheet after every delete.
class _DownloadedRoutesSheet extends StatefulWidget {
  const _DownloadedRoutesSheet({
    required this.initialItems,
    required this.scrollController,
    required this.ref,
  });

  final List<OfflineRouteRecord> initialItems;
  final ScrollController scrollController;
  final WidgetRef ref;

  @override
  State<_DownloadedRoutesSheet> createState() => _DownloadedRoutesSheetState();
}

class _DownloadedRoutesSheetState extends State<_DownloadedRoutesSheet> {
  late List<OfflineRouteRecord> _items = [...widget.initialItems];
  String? _removingId;

  Future<void> _remove(OfflineRouteRecord item) async {
    setState(() => _removingId = item.id);
    try {
      await removeDownloadedRoute(widget.ref, item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((entry) => entry.id != item.id).toList();
        _removingId = null;
      });
      if (_items.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      if (!mounted) return;
      setState(() => _removingId = null);
      showAppNotice(context, 'Не удалось удалить копию маршрута');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Размеры и цвета сняты со скрина дизайнера («Настройки Оффлайн»,
    // 590×1278 при 1.5x): строка 64 высотой на голубой заливке #EDF4FC,
    // синий кружок с галочкой 31, серый крестик справа.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Скачанные маршруты',
                  style: AppTypography.settingsRowTitle.copyWith(fontSize: 17),
                ),
              ),
              Text(
                '${_items.length}',
                style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              final busy = _removingId == item.id;
              return _DownloadedRouteRow(
                title: item.route.name,
                subtitle:
                    '${item.route.stops.length} '
                    '${_stopWord(item.route.stops.length)} • '
                    '${SettingsOfflineScreen._downloadDate(item.downloadedAt)}',
                busy: busy,
                onOpen: busy
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        unawaited(
                          context.pushNamed(
                            AppRouteNames.routeDetails,
                            pathParameters: {'id': item.id},
                            extra: item.route,
                          ),
                        );
                      },
                onRemove: () => unawaited(_remove(item)),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _stopWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'остановок';
    if (mod10 == 1) return 'остановка';
    if (mod10 >= 2 && mod10 <= 4) return 'остановки';
    return 'остановок';
  }
}

/// Строка скачанного маршрута — точная копия строки с макета: голубая
/// плашка, синий кружок с галочкой, две строки текста и крестик.
class _DownloadedRouteRow extends StatelessWidget {
  const _DownloadedRouteRow({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onOpen,
    required this.onRemove,
  });

  static const _fill = Color(0xFFEDF4FC);
  static const _rowHeight = 64.0;

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              const SizedBox(width: 15),
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 31,
                color: AppColors.accentBlueIcon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.settingsRowSubtitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Semantics(
                  button: true,
                  label: 'Удалить скачанную копию',
                  child: InkResponse(
                    onTap: onRemove,
                    radius: 22,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(10, 10, 12, 10),
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFF86898E),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
