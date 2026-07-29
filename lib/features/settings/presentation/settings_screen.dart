import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routePath = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsPreferencesProvider);
    return SettingsScaffold(
      headerOverlay: TravelPlusBanner(
        active: prefs.travelPlusActive,
        subtitle: prefs.travelPlusActive
            ? 'Активна до ${prefs.travelPlusExpiresLabel}'
            : 'Первый месяц бесплатно',
        onTap: () => context.pushNamed(AppRouteNames.settingsTravelPlus),
      ),
      children: [
        SettingsNavTile(
          title: 'Настройки профиля',
          subtitle: 'Гибкие настройки для удоства',
          icon: Icons.person_outline_rounded,
          onTap: () => context.pushNamed(AppRouteNames.settingsAccount),
        ),
        SettingsNavTile(
          title: 'Уведомления',
          subtitle: 'Гибкие настройки для удоства',
          icon: Icons.notifications_none_rounded,
          onTap: () => context.pushNamed(AppRouteNames.settingsNotifications),
        ),
        SettingsNavTile(
          title: 'Оффлайн маршруты',
          subtitle: 'Настройка скачивания маршрутов',
          icon: Icons.download_outlined,
          onTap: () => context.pushNamed(AppRouteNames.settingsOffline),
        ),
        SettingsNavTile(
          title: prefs.travelPlusActive
              ? 'Поддержка и обратная связь'
              : 'Поддержка',
          subtitle: 'Поможем с любым вопросом',
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => context.pushNamed(AppRouteNames.settingsSupport),
        ),
        SettingsNavTile(
          title: 'О сервисе',
          subtitle: 'Вся важная документация',
          icon: Icons.description_outlined,
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Документация сервиса появится позже'),
                ),
              );
          },
        ),
      ],
    );
  }
}
