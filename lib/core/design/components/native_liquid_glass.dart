import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Former platform-view id (`ios/Runner/LiquidGlassPlatformView.swift`).
///
/// A `UiKitView` + `UIGlassEffect` punches a hole through the Flutter layer and
/// blurs the **native** backdrop (often black), not Flutter widgets underneath.
/// That made search/filter/CTAs look like dark matte pills. Product chrome uses
/// Flutter `BackdropFilter` glass / light control surfaces instead.
const nativeLiquidGlassViewType = 'crimeatrip/liquid_glass';

/// Override used by widget/golden tests (kept for call-site compatibility).
bool forceFlutterLiquidGlassFallback = false;

/// Native platform-view Liquid Glass is disabled for product chrome.
bool shouldUseNativeLiquidGlass(BuildContext context) {
  // Always false: see [nativeLiquidGlassViewType].
  // [context] / [forceFlutterLiquidGlassFallback] kept for call-site stability.
  assert(context.mounted || !context.mounted);
  return false;
}

enum NativeLiquidGlassShape { rect, capsule, circle }

/// Adaptive glass chrome: light Flutter frosted glass (no `UiKitView`).
class AppAdaptiveGlassSurface extends StatelessWidget {
  const AppAdaptiveGlassSurface({
    required this.child,
    this.borderRadius = AppRadii.card,
    this.blur = 18,
    this.fillColor = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    this.borderWidth = 1,
    this.shape = NativeLiquidGlassShape.rect,
    this.interactive = false,
    this.boxShadow = AppShadows.glass,
    this.contentColor,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final NativeLiquidGlassShape shape;

  /// Reserved for a future native-capable glass bridge.
  final bool interactive;
  final List<BoxShadow> boxShadow;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    final radius = shape == NativeLiquidGlassShape.circle
        ? AppRadii.circle
        : borderRadius;

    return AppGlassSurface(
      borderRadius: radius,
      blur: blur,
      fillColor: fillColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      boxShadow: boxShadow,
      contentColor: contentColor,
      child: child,
    );
  }
}
