import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// 4-digit OTP UI. Accepts any complete code in Phase 5 (mock).
class AuthOtpScreen extends ConsumerStatefulWidget {
  const AuthOtpScreen({super.key});

  static const routePath = '/auth/otp';

  @override
  ConsumerState<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends ConsumerState<AuthOtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  var _privacyAccepted = false;
  var _personalDataAccepted = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _canSubmit =>
      _code.length == 4 && _privacyAccepted && _personalDataAccepted;

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _startJourney() {
    if (!_canSubmit) {
      return;
    }
    ref.read(sessionProvider.notifier).completeOnboarding();
    context.goNamed(AppRouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 128, 24, 24),
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
                'ПОДТВЕРДИТЕ\nНОМЕР',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: AppFonts.rubik,
                  fontWeight: FontWeight.w800,
                  fontSize: 42,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 74,
                    height: 58,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.headlineSmall,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.mist,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.ink),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.ink),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 1.4,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              _ConsentTile(
                value: _privacyAccepted,
                onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
                label: 'Согласен с политикой конфиденциальности',
              ),
              _ConsentTile(
                value: _personalDataAccepted,
                onChanged: (v) =>
                    setState(() => _personalDataAccepted = v ?? false),
                label: 'Согласен на обработку персональных данных',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 19),
                  ),
                  onPressed: _canSubmit ? _startJourney : null,
                  child: const Text('Начать путешествие'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
