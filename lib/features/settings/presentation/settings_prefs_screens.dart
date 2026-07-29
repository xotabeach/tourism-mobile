import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

class SettingsNotificationsScreen extends ConsumerWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsPreferencesProvider);
    final controller = ref.read(settingsPreferencesProvider.notifier);
    return SettingsScaffold(
      title: 'Настройки уведомлений:',
      showSave: true,
      children: [
        SettingsToggleTile(
          title: 'Пуш-уведомления',
          subtitle: 'Уведомления из приложения',
          icon: Icons.notifications_none_rounded,
          value: prefs.pushEnabled,
          onChanged: controller.setPush,
        ),
        SettingsToggleTile(
          title: 'СМС',
          subtitle: 'Для оповещения без интернета',
          icon: Icons.smartphone_outlined,
          value: prefs.smsEnabled,
          onChanged: controller.setSms,
        ),
        SettingsToggleTile(
          title: 'Звуки и вибрация',
          subtitle: 'При приближении к точке',
          icon: Icons.vibration_rounded,
          value: prefs.hapticsEnabled,
          onChanged: controller.setHaptics,
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
          icon: Icons.download_outlined,
          value: prefs.autoDownloadFavorites,
          onChanged: controller.setAutoDownload,
        ),
        SettingsToggleTile(
          title: 'Спрашивать разрешение',
          subtitle: 'Перед каждым скачиванием',
          icon: Icons.help_outline_rounded,
          value: prefs.askBeforeDownload,
          onChanged: controller.setAskBeforeDownload,
        ),
        SettingsNavTile(
          title: 'Кэш приложения',
          subtitle: prefs.cacheSizeLabel,
          icon: Icons.notifications_none_rounded,
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
    ref.read(apiCacheRegistryProvider).invalidateAll();
    ref.invalidate(placesListProvider);
    ref.invalidate(routesListProvider);
    controller.clearCacheLabel();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Кеш API очищен')));
  }
}
