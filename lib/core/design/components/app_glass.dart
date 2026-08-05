import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';

/// Compositor-safe alpha for subtrees that contain backdrop filters.
class AppFilteredOpacity extends StatelessWidget {
  const AppFilteredOpacity({
    required this.opacity,
    required this.child,
    super.key,
  }) : assert(opacity >= 0 && opacity <= 1);

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity == 1) {
      return child;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        opacity,
        0,
      ]),
      child: child,
    );
  }
}

class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    required this.child,
    this.borderRadius = AppRadii.card,
    this.blur = 18,
    this.fillColor = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    this.borderWidth = 1,
    this.boxShadow = AppShadows.glass,
    this.showInnerHighlight = true,
    this.contentColor,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> boxShadow;
  final bool showInnerHighlight;

  /// Icon / label color sitting on this surface. On Android (no blur), white
  /// glyphs switch the fill to solid nav chrome; dark glyphs keep [fillColor].
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    // Android mid-range GPUs stall hard on live BackdropFilter during nav /
    // swipe animations. Blur is always dropped; solid black chrome is only used
    // when the control's icon/label is white (see [contentColor]).
    final effectiveBlur = AppPerf.glassBlur(blur);
    final darkChrome = AppPerf.useDarkGlassChrome(contentColor: contentColor);
    final effectiveFill = AppPerf.glassFill(
      fillColor,
      foreground: contentColor,
    );
    final effectiveBorder = AppPerf.glassBorder(
      borderColor,
      foreground: contentColor,
    );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: borderWidth),
        boxShadow: showInnerHighlight && !darkChrome
            ? const [
                BoxShadow(
                  color: AppColors.glassHighlight,
                  blurRadius: 0,
                  spreadRadius: -1,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: child,
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: effectiveBlur <= 0
              ? surface
              : BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: effectiveBlur,
                    sigmaY: effectiveBlur,
                  ),
                  child: surface,
                ),
        ),
      ),
    );
  }
}

class AppGlassPill extends StatelessWidget {
  const AppGlassPill({
    required this.child,
    this.blur = 18,
    this.fillColor = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.contentColor,
    super.key,
  });

  final Widget child;
  final double blur;
  final Color fillColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: AppRadii.capsule,
      blur: blur,
      fillColor: fillColor,
      borderColor: borderColor,
      contentColor: contentColor,
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppGlassCircle extends StatelessWidget {
  const AppGlassCircle({
    required this.child,
    this.dimension = 52,
    this.blur = 18,
    this.fillColor = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    this.contentColor,
    super.key,
  });

  final Widget child;
  final double dimension;
  final double blur;
  final Color fillColor;
  final Color borderColor;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: AppGlassSurface(
        borderRadius: AppRadii.circle,
        blur: blur,
        fillColor: fillColor,
        borderColor: borderColor,
        contentColor: contentColor,
        child: Center(child: child),
      ),
    );
  }
}

class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.dimension = 52,
    this.iconSize = 24,
    this.foregroundColor = AppColors.primaryInk,
    this.fillColor = AppColors.glassFill,
    super.key,
  }) : assert(
         (icon == null) != (iconAsset == null),
         'Provide exactly one of icon or iconAsset.',
       );

  final IconData? icon;
  final String? iconAsset;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double dimension;
  final double iconSize;
  final Color foregroundColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox.square(
          dimension: dimension,
          child: AppAdaptiveGlassSurface(
            borderRadius: AppRadii.circle,
            shape: NativeLiquidGlassShape.circle,
            interactive: onPressed != null,
            fillColor: fillColor,
            contentColor: foregroundColor,
            child: IconButton(
              onPressed: onPressed,
              icon: iconAsset == null
                  ? Icon(icon)
                  : AppAssetIcon(
                      iconAsset!,
                      size: iconSize,
                      color: foregroundColor,
                    ),
              iconSize: iconSize,
              color: foregroundColor,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: dimension,
                height: dimension,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppAdaptivePrimaryButton extends StatelessWidget {
  const AppAdaptivePrimaryButton({
    required this.label,
    required this.onPressed,
    this.height = 54,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      );
    }

    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: AppAdaptiveGlassSurface(
          borderRadius: AppRadii.capsule,
          blur: 28,
          shape: NativeLiquidGlassShape.capsule,
          interactive: enabled,
          // Light frosted capsule — dark ink tint reads as a matte gray pill.
          fillColor: Colors.white.withValues(alpha: enabled ? 0.42 : 0.2),
          borderColor: Colors.white.withValues(alpha: enabled ? 0.92 : 0.48),
          borderWidth: 1.2,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: enabled ? 0.16 : 0.05),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: enabled ? 0.35 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadii.capsule),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryInk.withValues(
                      alpha: enabled ? 1 : 0.44,
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
