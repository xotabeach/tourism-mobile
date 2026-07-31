import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

class SettingsTravelPlusScreen extends ConsumerWidget {
  const SettingsTravelPlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsPreferencesProvider);
    final controller = ref.read(settingsPreferencesProvider.notifier);
    final top = MediaQuery.paddingOf(context).top;

    final subtitle = prefs.travelPlusActive
        ? 'Активна до ${prefs.travelPlusExpiresLabel}'
        : 'Первый месяц бесплатно';

    if (prefs.travelPlusActive) {
      return ColoredBox(
        color: AppColors.pageSurface,
        child: Column(
          children: [
            TravelPlusHeroBackground(
              topInset: top,
              subtitle: subtitle,
              child: const SizedBox(height: 40),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.elevatedSurface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadii.settingsTile),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: AppColors.pageSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          TravelPlusHeroBackground(
            topInset: top,
            subtitle: subtitle,
            child: const SizedBox(height: 40),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadii.settingsTile),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Преимущества подписки:',
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _BenefitCard(
                    title: 'Неограниченный подбор',
                    subtitle:
                        'В бесплатной версии доступно всего 5 подборов в неделю',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitCard(
                    title: 'Отсутствие рекламы',
                    subtitle:
                        'С подпиской будут отсутствовать рекламные баннеры и видео',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitCard(
                    title: 'Больше функций при поиске',
                    subtitle:
                        'Открывается доступ к более точным фильтрам при подборе маршрутов',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Тарифы:',
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    period: 'ГОД',
                    price: '999 ₽/год',
                    note: '(12 мес. 83,25 ₽/мес.)',
                    highlighted: true,
                    onTap: () => controller.activateTravelPlus(yearly: true),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    period: 'МЕСЯЦ',
                    price: '99 ₽/мес',
                    note: '(1 мес. 1 188 ₽/год)',
                    highlighted: false,
                    onTap: () => controller.activateTravelPlus(yearly: false),
                  ),
                  const SizedBox(height: 16),
                  SettingsNavTile(
                    title: 'О сервисе',
                    subtitle: 'Вся важная документация',
                    iconAsset: AppIconography.settingsAbout,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Документация появится позже'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SettingsPrimaryButton(
                    label: 'Продолжить',
                    onPressed: () {
                      controller.activateTravelPlus(yearly: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Подписка активирована (мок)'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SettingsColors.link, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: SettingsColors.link,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.settingsRowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.settingsRowSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.period,
    required this.price,
    required this.note,
    required this.highlighted,
    required this.onTap,
  });

  final String period;
  final String price;
  final String note;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 72,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: highlighted
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: SettingsColors.yearGradientEndAlign,
                    colors: [
                      SettingsColors.yearGradientStart,
                      SettingsColors.yearGradientEnd,
                    ],
                  )
                : null,
            color: highlighted ? null : SettingsColors.monthFlat,
            border: Border.all(
              color: highlighted
                  ? const Color(0xFF4D7FF7)
                  : SettingsColors.monthBorder,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 14,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    period,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 56,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SettingsCircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onTap,
                    background: Colors.white.withValues(alpha: 0.20),
                    iconColor: Colors.white,
                    iconSize: 18,
                    size: 44,
                    glass: true,
                    borderColor: Colors.white.withValues(alpha: 0.45),
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
