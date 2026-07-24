import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_fonts.dart';
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
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    'КРЫМТРИП',
                    style: AppTextStyles.logo(
                      color: Colors.white.withValues(alpha: 0.62),
                    ).copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ПОСТРОЙ СВОЙ\nИДЕАЛЬНЫЙ\nВЫХОДНОЙ',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.08,
                      fontFamily: AppFonts.rubik,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ПУТЕШЕСТВУЙ, ДЕЛИСЬ,\nНАХОДИ, ВДОХНОВЛЯЙСЯ.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 20,
                      height: 1.22,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      fontFamily: AppFonts.rubik,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              context.goNamed(AppRouteNames.authIdentity),
                          child: const SizedBox.square(
                            dimension: 62,
                            child: Icon(
                              Icons.person,
                              color: AppColors.ink,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.22,
                            ),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 19),
                          ),
                          onPressed: () =>
                              context.goNamed(AppRouteNames.authIdentity),
                          child: const Text('Начать путешествие'),
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
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppColors.sunsetMid),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.02),
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.82),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
