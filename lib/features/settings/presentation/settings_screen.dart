import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routePath = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final travelPlus = ref.watch(travelPlusViewProvider);
    return SettingsScaffold(
      headerOverlay: TravelPlusBanner(
        active: travelPlus.active,
        subtitle: travelPlus.active
            ? 'Активна до ${travelPlus.expiresLabel}'
            : 'Первый месяц бесплатно',
        onTap: () => context.pushNamed(AppRouteNames.settingsTravelPlus),
      ),
      children: [
        SettingsNavTile(
          title: 'Настройки профиля',
          subtitle: 'Гибкие настройки для удоства',
          iconAsset: AppIconography.settingsProfile,
          onTap: () => context.pushNamed(AppRouteNames.settingsAccount),
        ),
        SettingsNavTile(
          title: 'Уведомления',
          subtitle: 'Гибкие настройки для удоства',
          iconAsset: AppIconography.settingsNotifications,
          onTap: () => context.pushNamed(AppRouteNames.settingsNotifications),
        ),
        SettingsNavTile(
          title: 'Оффлайн маршруты',
          subtitle: 'Настройка скачивания маршрутов',
          iconAsset: AppIconography.settingsOffline,
          onTap: () => context.pushNamed(AppRouteNames.settingsOffline),
        ),
        SettingsNavTile(
          title: 'История чатов с ИИ',
          subtitle: 'Прошлые подборки маршрутов',
          icon: Icons.forum_outlined,
          onTap: () => context.pushNamed(AppRouteNames.chatHistory),
        ),
        SettingsNavTile(
          title: travelPlus.active ? 'Поддержка и обратная связь' : 'Поддержка',
          subtitle: 'Поможем с любым вопросом',
          iconAsset: AppIconography.settingsSupport,
          onTap: () => context.pushNamed(AppRouteNames.settingsSupport),
        ),
        SettingsNavTile(
          title: 'О сервисе',
          subtitle: 'Вся важная документация',
          iconAsset: AppIconography.settingsAbout,
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
