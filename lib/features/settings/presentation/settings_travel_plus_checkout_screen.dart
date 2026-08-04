import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/settings/application/settings_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Mock checkout / activation for Travel+. Payment is not real.
class SettingsTravelPlusCheckoutScreen extends ConsumerStatefulWidget {
  const SettingsTravelPlusCheckoutScreen({
    super.key,
    this.initialYearly = false,
  });

  final bool initialYearly;

  @override
  ConsumerState<SettingsTravelPlusCheckoutScreen> createState() =>
      _SettingsTravelPlusCheckoutScreenState();
}

class _SettingsTravelPlusCheckoutScreenState
    extends ConsumerState<SettingsTravelPlusCheckoutScreen> {
  late bool _yearly;
  var _paymentExpanded = true;
  final _cardNumber = TextEditingController(text: '1234 1234 1234 1234');
  final _expiry = TextEditingController(text: '11/11');
  final _cvc = TextEditingController(text: '123');

  @override
  void initState() {
    super.initState();
    _yearly = widget.initialYearly;
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  String get _maskedLast4 {
    final digits = _cardNumber.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return '••••';
    }
    return '•••• ${digits.substring(digits.length - 4)}';
  }

  void _submit() {
    final digits = _cardNumber.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12 || digits.length > 19) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Проверьте номер карты')));
      return;
    }
    ref
        .read(settingsPreferencesProvider.notifier)
        .activateTravelPlus(yearly: _yearly, paymentLast4: digits);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Подписка оформлена (мок)')));
    context.goNamed(AppRouteNames.settingsTravelPlus);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final priceMain = _yearly ? '999 ₽/год' : '99 ₽/мес';
    final priceAlt = _yearly ? '83,25 ₽/мес' : '1 188 ₽/год';
    final dueTodayLabel = _yearly ? '999 ₽' : '99 ₽';

    return ColoredBox(
      color: AppColors.pageSurface,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.zero,
          children: [
            TravelPlusHeroBackground(
              topInset: top,
              subtitle: 'Оформление подписки',
              child: const SizedBox(height: 36),
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
                      'Выберите тариф:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CheckoutPlanCard(
                      period: 'ГОД',
                      price: '999 ₽/год',
                      note: '83,25 ₽/мес',
                      selected: _yearly,
                      badge: 'Выгода 17%',
                      onTap: () => setState(() => _yearly = true),
                    ),
                    const SizedBox(height: 10),
                    _CheckoutPlanCard(
                      period: 'МЕСЯЦ',
                      price: '99 ₽/мес',
                      note: '1 188 ₽/год',
                      selected: !_yearly,
                      onTap: () => setState(() => _yearly = false),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Способ оплаты:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SettingsFormCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _paymentExpanded = !_paymentExpanded,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadii.settingsTile,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.credit_card_rounded,
                                    color: SettingsColors.accentIcon,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Способ оплаты $_maskedLast4',
                                      style: AppTypography.settingsRowTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    _paymentExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_paymentExpanded) ...[
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: SettingsColors.hairline,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                14,
                              ),
                              child: Column(
                                children: [
                                  SettingsTextField(
                                    controller: _cardNumber,
                                    hintText: 'Номер карты',
                                    keyboardType: TextInputType.number,
                                    maxLength: 23,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SettingsTextField(
                                          controller: _expiry,
                                          hintText: 'ММ/ГГ',
                                          keyboardType: TextInputType.datetime,
                                          maxLength: 5,
                                          textInputAction: TextInputAction.next,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SettingsTextField(
                                          controller: _cvc,
                                          hintText: 'CVC',
                                          keyboardType: TextInputType.number,
                                          maxLength: 4,
                                          textInputAction: TextInputAction.done,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Итого:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SettingsFormCard(
                      child: Column(
                        children: [
                          _TotalRow(label: 'Тариф', value: priceMain),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'К оплате сегодня',
                                  style: AppTypography.settingsRowTitle,
                                ),
                              ),
                              Text(
                                dueTodayLabel,
                                style: AppTypography.settingsRowSubtitle
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '0 ₽',
                                style: AppTypography.settingsRowTitle.copyWith(
                                  color: SettingsColors.link,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              priceAlt,
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CheckoutInfoBanner(
                      icon: Icons.percent_rounded,
                      text:
                          'Первый месяц бесплатно. Оплата $dueTodayLabel начнет '
                          'списываться только со второго месяца пользования '
                          'подпиской',
                    ),
                    const SizedBox(height: 10),
                    const _CheckoutInfoBanner(
                      icon: Icons.error_outline_rounded,
                      text:
                          'Автопродление. Отменить автопродление можно в '
                          'настройках подписки в любой момент',
                    ),
                    const SizedBox(height: 18),
                    SettingsPrimaryButton(
                      label: 'Оформить подписку',
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutPlanCard extends StatelessWidget {
  const _CheckoutPlanCard({
    required this.period,
    required this.price,
    required this.note,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String period;
  final String price;
  final String note;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? SettingsColors.link : SettingsColors.hairline,
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (badge != null)
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EAF6E),
                      borderRadius: BorderRadius.circular(AppRadii.capsule),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period,
                            style: TextStyle(
                              fontFamily: AppFonts.rubik,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.settingsInk.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(price, style: AppTypography.settingsRowTitle),
                          const SizedBox(height: 2),
                          Text(note, style: AppTypography.settingsRowSubtitle),
                          const SizedBox(height: 6),
                          Text(
                            'Полный доступ ко всем преимуществам подписки',
                            style: AppTypography.settingsRowSubtitle.copyWith(
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? SettingsColors.link
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? SettingsColors.link
                              : const Color(0xFFC5C5C5),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.settingsRowTitle)),
        Text(value, style: AppTypography.settingsRowTitle),
      ],
    );
  }
}

class _CheckoutInfoBanner extends StatelessWidget {
  const _CheckoutInfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: SettingsColors.link),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.settingsRowSubtitle.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.settingsInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
