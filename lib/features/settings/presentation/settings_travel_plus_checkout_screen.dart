import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
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
              offset: const Offset(0, 4),
              child: Container(
                color: AppColors.pageSurface,
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsFormCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выберите тариф:',
                            style: AppTypography.settingsRowTitle.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
                          const SizedBox(height: 8),
                          _CheckoutPlanCard(
                            period: 'МЕСЯЦ',
                            price: '99 ₽/мес',
                            note: '1 188 ₽/год',
                            selected: !_yearly,
                            onTap: () => setState(() => _yearly = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Способ оплаты:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                                horizontal: 18,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF4FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.credit_card_rounded,
                                      color: SettingsColors.accentIcon,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Способ оплаты',
                                          style: AppTypography.settingsRowTitle
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _maskedLast4,
                                          style:
                                              AppTypography.settingsRowSubtitle,
                                        ),
                                      ],
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
                                18,
                                10,
                                18,
                                12,
                              ),
                              child: Column(
                                children: [
                                  _CheckoutLabeledField(
                                    label: 'Способ оплаты',
                                    controller: _cardNumber,
                                    keyboardType: TextInputType.number,
                                    maxLength: 23,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CheckoutLabeledField(
                                          label: 'Месяц/Год',
                                          controller: _expiry,
                                          keyboardType: TextInputType.datetime,
                                          maxLength: 5,
                                          textInputAction: TextInputAction.next,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _CheckoutLabeledField(
                                          label: 'CVC/CVV',
                                          controller: _cvc,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: SettingsColors.hairline),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _TotalRow(label: 'Тариф', value: priceMain),
                    ),
                    const Divider(height: 1, color: SettingsColors.hairline),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'К оплате сегодня:',
                              style: AppTypography.settingsRowTitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            dueTodayLabel,
                            style: AppTypography.settingsRowSubtitle.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '0 ₽',
                            style: AppTypography.settingsRowTitle.copyWith(
                              color: SettingsColors.link,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CheckoutInfoBanner(
                      icon: Icons.discount_outlined,
                      title: 'Первый месяц бесплатно',
                      subtitle:
                          'Оплата $dueTodayLabel начнет списываться только со второго месяца пользования подпиской',
                    ),
                    const SizedBox(height: 8),
                    const _CheckoutInfoBanner(
                      icon: Icons.shield_outlined,
                      title: 'Автопродление',
                      subtitle:
                          'Отменить автопродление можно в настройках подписки в любой момент',
                    ),
                    const SizedBox(height: 14),
                    SettingsPrimaryButton(
                      key: const ValueKey('travel-plus-checkout-submit'),
                      label: 'Оформить подписку',
                      height: 52,
                      textStyle: AppTypography.settingsCta.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 92),
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
          unawaited(AppHaptics.selectionClick());
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
          child: SizedBox(
            key: ValueKey('travel-plus-checkout-plan-$period'),
            height: 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              period,
                              style: AppTypography.settingsRowTitle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? SettingsColors.link
                                    : AppColors.settingsInk,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9F9EF),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.capsule,
                                    ),
                                  ),
                                  child: Text(
                                    badge!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.rubik,
                                      fontSize: 9.5,
                                      color: Color(0xFF2EAF6E),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Полный доступ ко всем преимуществам подписки',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            fontSize: 11,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: AppTypography.settingsRowTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? SettingsColors.link
                              : AppColors.settingsInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(note, style: AppTypography.settingsRowSubtitle),
                    ],
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
                        width: selected ? 0 : 1,
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
        Expanded(
          child: Text(
            label,
            style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: AppTypography.settingsRowTitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CheckoutLabeledField extends StatelessWidget {
  const _CheckoutLabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.settingsRowSubtitle),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: AppTypography.settingsRowTitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 7),
            counterText: '',
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: SettingsColors.hairline),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: SettingsColors.hairline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: SettingsColors.link, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutInfoBanner extends StatelessWidget {
  const _CheckoutInfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        key: ValueKey('travel-plus-info-$title'),
        height: 61,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: SettingsColors.link),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.settingsRowSubtitle.copyWith(
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
