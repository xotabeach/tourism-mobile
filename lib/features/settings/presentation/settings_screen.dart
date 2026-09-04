import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/domain/legal_documents.dart';
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
          iconAsset: AppIconography.settingsChatHistory,
          onTap: () => context.pushNamed(AppRouteNames.chatHistory),
        ),
        SettingsNavTile(
          title: travelPlus.active ? 'Поддержка и обратная связь' : 'Поддержка',
          subtitle: 'Поможем с любым вопросом',
          iconAsset: AppIconography.settingsSupport,
          onTap: () => context.pushNamed(AppRouteNames.settingsSupport),
        ),
        SettingsNavTile(
          title: 'О приложении',
          subtitle: 'Версия, история изменений, документы',
          iconAsset: AppIconography.settingsAbout,
          onTap: () => context.pushNamed(AppRouteNames.settingsAbout),
        ),
      ],
    );
  }
}

class SettingsAboutScreen extends ConsumerWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsScaffold(
      title: 'О приложении:',
      spaceChildren: false,
      children: [
        // История изменений идёт первой: её открывают чаще, чем документы.
        SettingsNavTile(
          title: 'История изменений',
          subtitle: 'Что нового в каждой версии',
          icon: Icons.history_rounded,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsChangelog),
        ),
        for (final document in legalDocuments) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: document.title,
            subtitle: document.subtitle,
            icon: document.icon,
            dense: true,
            onTap: () => context.pushNamed(
              AppRouteNames.settingsLegalDocument,
              pathParameters: {'id': document.id},
            ),
          ),
        ],
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Реквизиты компании',
          subtitle: 'Наименование, ИНН, ОГРН, адрес',
          icon: Icons.article_outlined,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsCompanyDetails),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Контактная информация',
          subtitle: 'Способы связи с командой',
          icon: Icons.mail_outline_rounded,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsContacts),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        const _DeviceAndVersionCard(),
      ],
    );
  }
}

/// Устройство и версия — карточка, которую человек переписывает в обращение
/// в поддержку. Собирается сама: спрашивать у человека модель телефона
/// бессмысленно, он её обычно не знает.
class _DeviceAndVersionCard extends ConsumerWidget {
  const _DeviceAndVersionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return SettingsFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Устройство и версия',
            style: AppTypography.settingsRowTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: describeDeviceAndVersion(config),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Собираем данные…',
                style: AppTypography.settingsRowSubtitle,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// «Версия 0.2.2 (14), iPhone 16, iOS 27» — одной строкой.
///
/// Живёт снаружи виджета, потому что тем же текстом подписывается обращение
/// в поддержку.
Future<String> describeDeviceAndVersion(AppConfig config) async {
  final parts = <String>[];
  try {
    final info = await PackageInfo.fromPlatform();
    final channel = config.environment == AppEnvironment.production
        ? ''
        : ' (${config.environment.name})';
    parts.add('Версия ${info.version} (${info.buildNumber})$channel');
  } on Object {
    // Версия не прочиталась — устройство всё равно покажем.
  }
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      parts.add(ios.utsname.machine);
      parts.add('iOS ${ios.systemVersion}');
    } else if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      parts.add('${android.manufacturer} ${android.model}');
      parts.add('Android ${android.version.release}');
    }
  } on Object {
    // На десктопе и в тестах плагина нет — строка просто короче.
  }
  return parts.isEmpty ? 'Не удалось определить' : parts.join(', ');
}
