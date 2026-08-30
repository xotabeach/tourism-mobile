import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
          onTap: () => context.pushNamed(AppRouteNames.settingsAbout),
        ),
      ],
    );
  }
}

class SettingsAboutScreen extends ConsumerWidget {
  const SettingsAboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showAppNotice(context, 'Не удалось открыть ссылку');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return SettingsScaffold(
      title: 'О сервисе:',
      spaceChildren: false,
      children: [
        SettingsFormCard(
          child: Row(
            children: [
              Text(
                config.appName,
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 14),
              ),
              const Spacer(),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Text(
                    info == null
                        ? '…'
                        : 'Версия ${info.version} (${info.buildNumber})',
                    style: AppTypography.settingsRowSubtitle,
                  );
                },
              ),
            ],
          ),
        ),
        if (config.privacyPolicyUrl != null) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: 'Политика конфиденциальности',
            icon: Icons.privacy_tip_outlined,
            dense: true,
            onTap: () => unawaited(_open(context, config.privacyPolicyUrl!)),
          ),
        ],
        if (config.termsUrl != null) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: 'Условия использования',
            icon: Icons.description_outlined,
            dense: true,
            onTap: () => unawaited(_open(context, config.termsUrl!)),
          ),
        ],
        if (config.supportEmail != null) ...[
          const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: 'Написать нам',
            subtitle: config.supportEmail,
            icon: Icons.mail_outline_rounded,
            dense: true,
            onTap: () =>
                unawaited(_open(context, 'mailto:${config.supportEmail}')),
          ),
        ],
      ],
    );
  }
}
