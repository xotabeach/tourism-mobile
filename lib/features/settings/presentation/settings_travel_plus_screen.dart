import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsTravelPlusScreen extends ConsumerWidget {
  const SettingsTravelPlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsPreferencesProvider);
    final top = MediaQuery.paddingOf(context).top;

    final subtitle = prefs.travelPlusActive
        ? 'Активна до ${prefs.travelPlusExpiresLabel}'
        : 'Первый месяц бесплатно';

    if (prefs.travelPlusActive) {
      return _TravelPlusActiveBody(topInset: top, prefs: prefs);
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
                  const SizedBox(height: 10),
                  const _BenefitCard(
                    title: 'Подбор с ИИ',
                    subtitle:
                        'Чат-ассистент поможет собрать маршрут под ваши задачи',
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
                    onTap: () => context.pushNamed(
                      AppRouteNames.settingsTravelPlusCheckout,
                      queryParameters: const {'yearly': 'true'},
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    period: 'МЕСЯЦ',
                    price: '99 ₽/мес',
                    note: '(1 мес. 1 188 ₽/год)',
                    highlighted: false,
                    onTap: () => context.pushNamed(
                      AppRouteNames.settingsTravelPlusCheckout,
                      queryParameters: const {'yearly': 'false'},
                    ),
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
                  // Bottom CTA lives in the shell nav («Продолжить»).
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelPlusActiveBody extends ConsumerWidget {
  const _TravelPlusActiveBody({required this.topInset, required this.prefs});

  final double topInset;
  final SettingsPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expires = prefs.travelPlusExpiresLabel;
    final nextCharge = prefs.travelPlusYearly ? '29.07.2027' : '29.08.2026';
    final tariffLabel = prefs.travelPlusYearly ? 'Год' : 'Месяц';
    final tariffPrice = prefs.travelPlusYearly ? '999 ₽/год' : '99 ₽/мес';

    return ColoredBox(
      color: AppColors.pageSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          TravelPlusHeroBackground(
            topInset: topInset,
            subtitle: 'Активна до $expires',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ваша подписка:',
                          style: AppTypography.settingsRowTitle.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const _MiniTravelBadge(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsFormCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _SubscriptionMetaRow(
                          icon: Icons.calendar_month_outlined,
                          title: 'Следующее списание',
                          subtitle: nextCharge,
                          trailing: _SoftBadge(
                            label: prefs.travelPlusDaysLeftLabel,
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: SettingsColors.hairline,
                        ),
                        _SubscriptionMetaRow(
                          icon: Icons.alarm_rounded,
                          title: 'Тариф',
                          subtitle: tariffLabel,
                          trailing: Text(
                            tariffPrice,
                            style: AppTypography.settingsRowTitle.copyWith(
                              color: SettingsColors.link,
                            ),
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: SettingsColors.hairline,
                        ),
                        _SubscriptionMetaRow(
                          icon: Icons.credit_card_rounded,
                          title: 'Способ оплаты',
                          subtitle: '•••• ${prefs.paymentLast4}',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Смена карты появится после подключения оплаты',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _ThanksBanner(),
                  const SizedBox(height: 20),
                  Text(
                    'Управление подпиской:',
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsNavTile(
                    title: 'Изменить тариф',
                    subtitle: 'Выбрать другой тарифный план',
                    icon: Icons.open_with_rounded,
                    onTap: () => context.pushNamed(
                      AppRouteNames.settingsTravelPlusCheckout,
                      queryParameters: {
                        'yearly': prefs.travelPlusYearly ? 'true' : 'false',
                      },
                    ),
                  ),
                  const SizedBox(height: SettingsMetrics.rowGap),
                  SettingsNavTile(
                    title: 'Отменить подписку',
                    subtitle: 'Подписка останется активной до $expires',
                    icon: Icons.confirmation_number_outlined,
                    onTap: () => _confirmCancel(context, ref, expires),
                  ),
                  const SizedBox(height: 16),
                  SettingsChatCta(
                    onTap: () => context.pushNamed(AppRouteNames.settingsChat),
                  ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String expiresLabel,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить подписку?'),
        content: Text(
          'Подписка останется активной до $expiresLabel. '
          'Автопродление будет отключено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    ref.read(settingsPreferencesProvider.notifier).cancelTravelPlus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Автопродление отключено (мок)')),
      );
  }
}

class _MiniTravelBadge extends StatelessWidget {
  const _MiniTravelBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Text(
        'ТРЕВЕЛ +',
        style: AppTypography.settingsRowTitle.copyWith(
          fontSize: 11,
          color: SettingsColors.link,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Text(
        label,
        style: AppTypography.settingsRowSubtitle.copyWith(
          color: SettingsColors.link,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SubscriptionMetaRow extends StatelessWidget {
  const _SubscriptionMetaRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: SettingsColors.accentIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.settingsRowTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.settingsRowSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}

class _ThanksBanner extends StatelessWidget {
  const _ThanksBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.settingsTile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: SettingsColors.link,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Спасибо, что вы с нами!',
                    style: AppTypography.settingsRowTitle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Вы получаете максимум возможностей для ваших '
                    'путешествий по Крыму',
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      fontSize: 12,
                      height: 1.35,
                    ),
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

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 0),
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
                right: 62,
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
