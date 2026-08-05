import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Full-bleed welcome matching Figma «Приветственный экран».
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const routePath = '/welcome';

  @override
  Widget build(BuildContext context) {
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
                      AppGlassCircle(
                        dimension: 54,
                        blur: 16,
                        fillColor: Colors.white.withValues(alpha: 0.82),
                        child: Semantics(
                          button: true,
                          label: 'Открыть профиль',
                          child: IconButton(
                            onPressed: () =>
                                context.goNamed(AppRouteNames.authIdentity),
                            icon: const AppAssetIcon(
                              AppIconography.profileSelected,
                              color: AppColors.primaryInk,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SizedBox(
                          height: 54,
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
                                onTap: () =>
                                    context.goNamed(AppRouteNames.authIdentity),
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
