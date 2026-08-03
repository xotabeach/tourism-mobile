import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Primary CTA used by the shell floating nav on route / Travel+ details.
class RouteStartButton extends StatelessWidget {
  const RouteStartButton({
    required this.onPressed,
    this.visibility = 1,
    this.morphProgress = 0,
    this.label = 'Пройти маршрут',
    this.compactAlignedRight = false,
    super.key,
  });

  final VoidCallback onPressed;
  final double visibility;
  final double morphProgress;
  final String label;
  final bool compactAlignedRight;

  @override
  Widget build(BuildContext context) {
    final progress = visibility.clamp(0.0, 1.0);
    final morph = morphProgress.clamp(0.0, 1.0);
    final liquidStretch = math.sin(math.pi * morph);
    final sideAlign = compactAlignedRight
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Transform.scale(
      alignment: morph > 0.5 ? sideAlign : Alignment.bottomCenter,
      scaleX: 1 + 0.025 * liquidStretch,
      scaleY: 1 - 0.045 * liquidStretch,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: AppGlassSurface(
          borderRadius: AppRadii.capsule,
          blur: 20 * progress,
          fillColor: AppColors.activeNavigationFill.withValues(
            alpha: 0.96 * progress,
          ),
          borderColor: Colors.white.withValues(alpha: 0.28 * progress),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16 * progress),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          child: IgnorePointer(
            ignoring: progress < 0.99,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.capsule),
                onTap: onPressed,
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.button.copyWith(
                      fontSize: 17,
                      color: Colors.white.withValues(alpha: progress),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
