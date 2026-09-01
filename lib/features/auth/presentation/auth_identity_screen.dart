import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';
import 'package:tourism_mobile/core/validation/display_name.dart';
import 'package:tourism_mobile/features/auth/presentation/ru_phone_input_formatter.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Name + phone entry. Mock only — Phase 6 wires real auth API.
class AuthIdentityScreen extends ConsumerStatefulWidget {
  const AuthIdentityScreen({super.key});

  static const routePath = '/auth/identity';

  @override
  ConsumerState<AuthIdentityScreen> createState() => _AuthIdentityScreenState();
}

class _AuthIdentityScreenState extends ConsumerState<AuthIdentityScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'registration-name');
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  var _submitting = false;
  var _registrationRequired = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: '${RuPhoneInputFormatter.countryPrefix} ',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    final phone = RuPhoneInputFormatter.toE164(_phoneController.text);
    final name = _registrationRequired ? _nameController.text : null;
    ref
        .read(sessionProvider.notifier)
        .saveIdentity(displayName: name, phone: phone);
    try {
      final result = await ref
          .read(sessionProvider.notifier)
          .requestOtp(displayName: name);
      if (result.registrationRequired) {
        if (!mounted) {
          return;
        }
        setState(() => _registrationRequired = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _nameFocus.requestFocus();
          }
        });
        return;
      }
      if (!result.otpSent) {
        throw StateError('OTP was not sent');
      }
      if (!mounted) {
        return;
      }
      // Push so the OTP screen can swipe / pop back to phone entry.
      await context.pushNamed(AppRouteNames.authOtp);
    } on Object {
      if (!mounted) {
        return;
      }
      showAppNotice(context, 'Не удалось отправить код. Попробуйте ещё раз.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'КРЫМТРИП',
                  style: AppTextStyles.logo(
                    color: AppColors.ink.withValues(alpha: 0.45),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _registrationRequired
                      ? 'ДАВАЙТЕ\nЗНАКОМИТЬСЯ'
                      : 'ВОЙДИТЕ\nПО НОМЕРУ',
                  style: AppTextStyles.displayTitle(fontSize: 40),
                ),
                const SizedBox(height: 36),
                if (_registrationRequired) ...[
                  TextFormField(
                    // Both fields are TextFormFields in one Column, and the
                    // name field appears at the index the phone field used to
                    // occupy. Without keys Flutter matches children by index
                    // and type, reuses the phone field's element — and with it
                    // the live text input connection still configured as
                    // TextInputType.phone — so the numeric keyboard stayed up
                    // while the user was being asked for their name.
                    key: const ValueKey('auth-name-field'),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: DisplayNamePolicy.maxLength,
                    decoration: const InputDecoration(
                      hintText: 'Введите ваше имя',
                      counterText: '',
                    ),
                    validator: DisplayNamePolicy.validationError,
                    onFieldSubmitted: (_) => _continue(),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const ValueKey('auth-phone-field'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [RuPhoneInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: 'Введите ваш номер телефона',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12),
                      child: AppAssetIcon(
                        AppIconography.phone,
                        size: 24,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (!RuPhoneInputFormatter.isComplete(value ?? '')) {
                      return 'Введите номер в формате +7 XXX XXX-XX-XX';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _continue(),
                ),
                if (!_registrationRequired) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Если аккаунта ещё нет, имя понадобится только один раз — при регистрации.',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.ink.withValues(alpha: 0.58),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AppAdaptivePrimaryButton(
                  label: 'Продолжить',
                  onPressed: _submitting ? null : _continue,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
