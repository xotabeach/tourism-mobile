import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Solid grey of the blocked «Пройти маршрут» (DESIGN-4 №6, #646464).
const _unavailableFill = Color(0xFF646464);

/// Primary CTA used by the shell floating nav on route / Travel+ details.
class RouteStartButton extends StatelessWidget {
  const RouteStartButton({
    required this.onPressed,
    this.visibility = 1,
    this.morphProgress = 0,
    this.label = 'Пройти маршрут',
    this.compactAlignedRight = false,
    this.unavailable = false,
    this.semanticsLabel,
    super.key,
  });

  /// Looks inactive but stays tappable: the press re-checks with the server,
  /// which may have lifted the restriction in the meantime.
  final bool unavailable;

  /// Spoken instead of [label] when set (a screen reader hears that the
  /// button can still be pressed to re-check).
  final String? semanticsLabel;

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
          fillColor:
              (unavailable ? _unavailableFill : AppColors.activeNavigationFill)
                  .withValues(alpha: 0.96 * progress),
          // DESIGN-4 №6 draws the blocked button flat: no glass rim, no lift.
          borderColor: unavailable
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.28 * progress),
          boxShadow: [
            if (!unavailable)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16 * progress),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
          child: IgnorePointer(
            ignoring: progress < 0.99,
            child: Semantics(
              button: true,
              enabled: true,
              label: semanticsLabel ?? label,
              excludeSemantics: true,
              onTap: onPressed,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.capsule),
                  onTap: onPressed,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.button.copyWith(
                        // DESIGN-4 №6: the blocked state carries a two-line
                        // «Прохождение временно недоступно: через …».
                        fontSize: unavailable ? 15 : 17,
                        fontWeight: unavailable ? FontWeight.w400 : null,
                        height: unavailable ? 1.25 : null,
                        color: Colors.white.withValues(alpha: progress),
                      ),
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
