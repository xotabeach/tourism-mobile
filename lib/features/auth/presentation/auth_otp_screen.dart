import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
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

class _AuthOtpScreenState extends ConsumerState<AuthOtpScreen>
    with WidgetsBindingObserver {
  static const _length = 4;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  var _privacyAccepted = false;
  var _personalDataAccepted = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onCodeChanged);
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    // Open the keyboard on the first cell as soon as the screen settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openKeyboard(caretAt: 0);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onCodeChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS dismisses the soft keyboard on background but often leaves the
    // FocusNode focused, so a later requestFocus() is a no-op. Drop focus so
    // the next cell tap can re-attach the input connection.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _focusNode.unfocus();
    }
  }

  String get _code => _controller.text;

  bool get _canSubmit {
    final consentsRequired = ref.read(sessionProvider).otpConsentsRequired;
    return _code.length == _length &&
        (!consentsRequired || (_privacyAccepted && _personalDataAccepted));
  }

  void _onCodeChanged() {
    final cleaned = _controller.text.replaceAll(RegExp(r'\D'), '');
    final clipped = cleaned.length > _length
        ? cleaned.substring(0, _length)
        : cleaned;
    if (clipped != _controller.text) {
      _controller.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      return;
    }
    setState(() {});
  }

  void _openKeyboard({required int caretAt}) {
    final offset = caretAt.clamp(0, _code.length);
    if (_focusNode.hasFocus) {
      // Force a fresh input connection when focus is stale (common after resume).
      _focusNode.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _attachKeyboard(offset);
      });
      return;
    }
    _attachKeyboard(offset);
  }

  void _attachKeyboard(int offset) {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(offset: offset);
    // Belt-and-suspenders for platforms that keep focus without showing IME.
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
  }

  void _focusAt(int index) {
    _openKeyboard(caretAt: index);
  }

  void _goBackToPhone() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(AppRouteNames.authIdentity);
  }

  Future<void> _startJourney() async {
    if (!_canSubmit || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .verifyOtp(
            code: _code,
            privacyAccepted: _privacyAccepted,
            personalDataAccepted: _personalDataAccepted,
          );
      if (!mounted) {
        return;
      }
      context.goNamed(AppRouteNames.home);
    } on Object {
      if (!mounted) {
        return;
      }
      showAppNotice(context, 'Не удалось подтвердить код.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final consentsRequired = ref.watch(
      sessionProvider.select((value) => value.otpConsentsRequired),
    );

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppGlassIconButton(
                semanticLabel: 'Назад',
                icon: Icons.arrow_back_ios_new_rounded,
                dimension: 44,
                iconSize: 18,
                onPressed: _goBackToPhone,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 19),
              SizedBox(
                height: _OtpBox.rowHeight,
                child: Stack(
                  children: [
                    // Real editable surface: one field so backspace always works.
                    Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        style: const TextStyle(color: Colors.transparent),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_length),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < _length; index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _OtpBox(
                              digit: index < code.length ? code[index] : null,
                              active:
                                  _focusNode.hasFocus &&
                                  (index == code.length ||
                                      (code.length == _length &&
                                          index == _length - 1)),
                              onTap: () => _focusAt(index),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (consentsRequired) ...[
                const SizedBox(height: 23),
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
              ],
              const SizedBox(height: 26),
              AppAdaptivePrimaryButton(
                label: consentsRequired ? 'Начать путешествие' : 'Войти',
                onPressed: _canSubmit && !_submitting ? _startJourney : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visual OTP cell. Digits stay centered while height and type grow together.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.active,
    required this.onTap,
  });

  static const double emptyHeight = 58;
  static const double filledHeight = 70;
  static const double emptyFontSize = 22;
  static const double filledFontSize = 28;
  static const double rowHeight = 74;

  final String? digit;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? AppMotion.reduced : AppMotion.emphasized;
    final curve = reduceMotion ? Curves.linear : AppMotion.spring;
    final filled = digit != null;

    return Semantics(
      button: true,
      label: filled ? 'Цифра $digit' : 'Пустое поле кода',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          width: double.infinity,
          height: filled ? filledHeight : emptyHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? Colors.white : AppColors.controlSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled || active ? AppColors.ink : const Color(0xFF4E4E52),
              width: filled || active ? 1.8 : 1.4,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: curve,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: filled ? filledFontSize : emptyFontSize,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0,
              color: AppColors.ink,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            child: filled
                ? Text(digit!)
                : active
                ? const _OtpCaret()
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Blinking caret shown in the currently selected empty cell.
class _OtpCaret extends StatefulWidget {
  const _OtpCaret();

  @override
  State<_OtpCaret> createState() => _OtpCaretState();
}

class _OtpCaretState extends State<_OtpCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _CaretBar(opacity: 1);
    }
    return FadeTransition(
      opacity: _controller.drive(
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(1), weight: 45),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 5),
          TweenSequenceItem(tween: ConstantTween(0), weight: 45),
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 5),
        ]),
      ),
      child: const _CaretBar(opacity: 1),
    );
  }
}

class _CaretBar extends StatelessWidget {
  const _CaretBar({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 2,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(1),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 26,
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
                ),
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
      ),
    );
  }
}
