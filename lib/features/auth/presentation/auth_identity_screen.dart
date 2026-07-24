import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';
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
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();

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
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ref
        .read(sessionProvider.notifier)
        .saveIdentity(
          displayName: _nameController.text,
          phone: RuPhoneInputFormatter.toE164(_phoneController.text),
        );
    context.goNamed(AppRouteNames.authOtp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 128, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'КРЫМТРИП',
                  style: AppTextStyles.logo(
                    color: AppColors.ink.withValues(alpha: 0.42),
                  ).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 24),
                Text(
                  'ЗДРАВСТВУЙ,\nПУТНИК',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: AppFonts.rubik,
                    fontWeight: FontWeight.w800,
                    fontSize: 42,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 34),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Введите ваше имя',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Укажите имя';
                    }
                    if (trimmed.length > 80) {
                      return 'Слишком длинное имя';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [RuPhoneInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: '+7 999 123-45-67',
                  ),
                  validator: (value) {
                    if (!RuPhoneInputFormatter.isComplete(value ?? '')) {
                      return 'Введите номер в формате +7 XXX XXX-XX-XX';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 19),
                    ),
                    onPressed: _continue,
                    child: const Text('Продолжить'),
                  ),
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
