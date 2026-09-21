import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/startup/splash_frames.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Full-bleed welcome matching Figma «Приветственный экран».
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  static const routePath = '/welcome';

  static const double _profileButtonSize = 54;
  static const double _avatarBorderWidth = 2;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// The session ended at start-up (the server rejected the saved login).
  /// Kept here, not read from the session, because the session flag is
  /// one-shot: it is cleared as soon as this screen has picked it up.
  var _sessionExpired = false;

  @override
  void initState() {
    super.initState();
    _pickUpExpiredNotice(ref.read(sessionProvider).sessionExpiredNotice);
  }

  void _pickUpExpiredNotice(bool pending) {
    if (!pending) {
      return;
    }
    _sessionExpired = true;
    // Clearing notifies listeners (the router): never during build.
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          ref.read(sessionProvider.notifier).consumeSessionExpiredNotice();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sessionProvider.select((s) => s.sessionExpiredNotice), (
      _,
      pending,
    ) {
      if (pending) {
        setState(() => _pickUpExpiredNotice(pending));
      }
    });
    final session = ref.watch(
      sessionProvider.select(
        (s) => (isAuthenticated: s.isAuthenticated, avatarUrl: s.avatarUrl),
      ),
    );
    final config = ref.watch(appConfigProvider);
    final authenticated = session.isAuthenticated;

    void enterApp() {
      context.goNamed(
        authenticated ? AppRouteNames.home : AppRouteNames.authIdentity,
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _WelcomeBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    'КРЫМТРИП',
                    style: AppTypography.welcomeBrand.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      shadows: _textShade,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ПОСТРОЙ СВОЙ\nИДЕАЛЬНЫЙ\nВЫХОДНОЙ',
                    style: AppTypography.welcomeTitle.copyWith(
                      color: Colors.white,
                      shadows: _textShade,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ПУТЕШЕСТВУЙ, ДЕЛИСЬ,\nНАХОДИ, ВДОХНОВЛЯЙСЯ.',
                    style: AppTypography.welcomeSubtitle.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      shadows: _textShade,
                    ),
                  ),
                  if (_sessionExpired) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Сессия истекла, войдите снова',
                      key: const ValueKey('welcome-session-expired'),
                      style: AppTypography.welcomeSubtitle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: _textShade,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 28),
                  Row(
                    children: [
                      _WelcomeProfileButton(
                        authenticated: authenticated,
                        avatarUrl: session.avatarUrl,
                        config: config,
                        onPressed: enterApp,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _WelcomeStartButton(onPressed: enterApp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeProfileButton extends StatelessWidget {
  const _WelcomeProfileButton({
    required this.authenticated,
    required this.avatarUrl,
    required this.config,
    required this.onPressed,
  });

  final bool authenticated;
  final String? avatarUrl;
  final AppConfig config;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (authenticated) {
      final avatar = AppImages.avatarProvider(
        config: config,
        avatarUrl: avatarUrl,
      );
      return Semantics(
        button: true,
        label: 'Открыть приложение',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Ink(
              width: WelcomeScreen._profileButtonSize,
              height: WelcomeScreen._profileButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black,
                  width: WelcomeScreen._avatarBorderWidth,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(WelcomeScreen._avatarBorderWidth),
                child: ClipOval(
                  child: Image(
                    image: avatar,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Открыть профиль',
      excludeSemantics: true,
      child: Material(
        color: _welcomeButtonFill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: WelcomeScreen._profileButtonSize,
            child: Center(
              child: AppAssetIcon(
                AppIconography.profileSelected,
                size: 28,
                color: AppColors.primaryInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft shade behind the white text, so it holds over the bright sunset
/// band without darkening the whole picture.
const _textShade = [Shadow(color: Color(0x66000000), blurRadius: 14)];

/// Solid, not glass: over the photo a see-through glass button took on the
/// dark foreground and its dark label all but disappeared.
const _welcomeButtonFill = Color(0xF2FFFFFF);

class _WelcomeStartButton extends StatelessWidget {
  const _WelcomeStartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Начать путешествие';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: _welcomeButtonFill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: WelcomeScreen._profileButtonSize,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryInk,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The same «day» frame the preloader ends on, so the hand-over from
        // the preloader is seamless.
        const SplashDayBackdrop(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Only as much shade as the white text needs: the picture is the
              // point of this screen, and a heavy scrim buried it and the
              // buttons with it.
              colors: [
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.22),
                Colors.black.withValues(alpha: 0.42),
              ],
              stops: const [0, 0.5, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}
