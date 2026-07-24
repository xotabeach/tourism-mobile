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
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
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
                'ПОДТВЕРДИТЕ\nНОМЕР',
                style: AppTextStyles.displayTitle(fontSize: 40),
              ),
              const SizedBox(height: 32),
              Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 3 ? 10 : 0),
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(letterSpacing: 0.4),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.ink,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.ink,
                                width: 1,
                              ),
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
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              _ConsentTile(
                value: _privacyAccepted,
                onChanged: (v) => setState(() => _privacyAccepted = v),
                label: 'Я соглашаюсь с политикой конфиденциальности',
              ),
              _ConsentTile(
                value: _personalDataAccepted,
                onChanged: (v) => setState(() => _personalDataAccepted = v),
                label: 'Я соглашаюсь на обработку персональных данных',
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? AppColors.ink : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.ink : AppColors.inkSoft,
                  width: 1.4,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  height: 1.35,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.ink.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
