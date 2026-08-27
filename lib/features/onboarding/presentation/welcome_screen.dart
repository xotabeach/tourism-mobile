import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Full-bleed welcome matching Figma «Приветственный экран».
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const routePath = '/welcome';

  static const double _profileButtonSize = 54;
  static const double _avatarBorderWidth = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ПОСТРОЙ СВОЙ\nИДЕАЛЬНЫЙ\nВЫХОДНОЙ',
                    style: AppTypography.welcomeTitle.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ПУТЕШЕСТВУЙ, ДЕЛИСЬ,\nНАХОДИ, ВДОХНОВЛЯЙСЯ.',
                    style: AppTypography.welcomeSubtitle.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
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
                        child: SizedBox(
                          height: _profileButtonSize,
                          child: AppGlassSurface(
                            borderRadius: 999,
                            blur: 18,
                            fillColor: Colors.white.withValues(alpha: 0.22),
                            borderColor: Colors.white.withValues(alpha: 0.52),
                            contentColor: Colors.white,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: enterApp,
                                child: Center(
                                  child: Text(
                                    'Начать путешествие',
                                    style: AppTypography.button.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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

    return AppGlassCircle(
      dimension: WelcomeScreen._profileButtonSize,
      blur: 16,
      fillColor: Colors.white.withValues(alpha: 0.82),
      child: Semantics(
        button: true,
        label: 'Открыть профиль',
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Открыть профиль',
          icon: const AppAssetIcon(
            AppIconography.profileSelected,
            color: AppColors.primaryInk,
            size: 28,
          ),
          padding: EdgeInsets.zero,
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
        Image.asset(
          AppImages.welcomeSunset,
          fit: BoxFit.cover,
          alignment: const Alignment(-0.12, 0),
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppColors.sunsetMid),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.79),
              ],
              stops: const [0, 0.44, 1],
            ),
          ),
        ),
      ],
    );
  }
}
