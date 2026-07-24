import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 38, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'КРЫМТРИП',
                style: AppTextStyles.logo(
                  color: AppColors.ink.withValues(alpha: 0.45),
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ПОДТВЕРДИТЕ\nНОМЕР',
                style: AppTextStyles.displayTitle(fontSize: 41, height: 1.2),
              ),
              const SizedBox(height: 27),
              Row(
                children: [
                  for (var index = 0; index < 4; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _OtpField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 31),
              _ConsentTile(
                value: _privacyAccepted,
                onChanged: (v) => setState(() => _privacyAccepted = v),
                document: 'политикой конфиденциальности',
              ),
              const SizedBox(height: 8),
              _ConsentTile(
                value: _personalDataAccepted,
                onChanged: (v) => setState(() => _personalDataAccepted = v),
                document: 'обработкой персональных данных',
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _startJourney : null,
                  child: const Text('Начать путешествие'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One code box that pops open when its digit lands.
class _OtpField extends StatefulWidget {
  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  var _filled = false;

  @override
  void initState() {
    super.initState();
    _filled = widget.controller.text.isNotEmpty;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.08), weight: 42),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 58),
    ]).animate(CurvedAnimation(parent: _controller, curve: AppMotion.standard));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final filled = value.isNotEmpty;
    if (filled && !_filled && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_controller.forward(from: 0));
    }
    setState(() => _filled = filled);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: reduceMotion ? AppMotion.reduced : AppMotion.normal,
        curve: AppMotion.standard,
        height: 58,
        decoration: BoxDecoration(
          color: _filled ? Colors.white : AppColors.controlSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _filled ? AppColors.ink : const Color(0xFF4E4E52),
            width: _filled ? 1.8 : 1.4,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(letterSpacing: 0.4),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: const InputDecoration(
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
          ),
          onChanged: _handleChanged,
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.document,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String document;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
      color: AppColors.ink,
    );

    return Semantics(
      checked: value,
      label: 'Я соглашаюсь с $document',
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? AppColors.ink : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.ink : const Color(0xFFCACACD),
                  width: 1.4,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Я соглашаюсь\nс '),
                    TextSpan(
                      text: document,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                style: labelStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
