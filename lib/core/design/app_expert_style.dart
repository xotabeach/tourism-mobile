import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';

/// Shared visual language for verified CrimeaTrip experts.
abstract final class AppExpertStyle {
  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2997FF), Color(0xFF9B51FF)],
  );

  static const borderWidth = 2.0;
}

class AppExpertFrame extends StatelessWidget {
  const AppExpertFrame({
    required this.isExpert,
    required this.borderRadius,
    required this.child,
    this.borderWidth = AppExpertStyle.borderWidth,
    super.key,
  });

  final bool isExpert;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isExpert) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppExpertStyle.gradient,
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            (borderRadius.topLeft.x - borderWidth).clamp(0, double.infinity),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppExpertBadge extends StatelessWidget {
  const AppExpertBadge({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Эксперт',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppExpertStyle.gradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: compact ? 2 : 3,
          ),
          child: Text(
            'Эксперт',
            maxLines: 1,
            style: AppTypography.chip.copyWith(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
