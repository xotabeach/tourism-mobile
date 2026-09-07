import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';

/// «Жидкое стекло» в настройках (iOS only) — см.
/// `LiquidGlassPreferenceController`. Плоское статическое поле, а не
/// провайдер: кнопки ниже — простые StatelessWidget, как и остальной core/design,
/// и не должны становиться Consumer ради одного флага. [TourismApp] держит
/// `ref.watch(liquidGlassEnabledProvider)` в корне, чтобы смена настройки
/// перестраивала всё дерево — тот же приём, что и для `reduceMotion`.
abstract final class AppGlassSettings {
  static bool enabled = true;
}

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
              // `grouped` shares one backdrop sample with every sibling glass
              // surface under the same [BackdropGroup] — without an enclosing
              // group it resolves to a null key and behaves exactly like a
              // plain BackdropFilter, so this is safe everywhere.
              : BackdropFilter.grouped(
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
    if (Theme.of(context).platform == TargetPlatform.iOS &&
        AppGlassSettings.enabled) {
      // Passive surface, no onTap of its own (e.g. a decorative affordance
      // inside a tappable card) — GlassContainer, not GlassButton/IconButton.
      return GlassContainer(
        width: dimension,
        height: dimension,
        shape: const LiquidOval(),
        child: Center(child: child),
      );
    }
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
    this.iconWidget,
    this.dimension = 52,
    this.iconSize = 24,
    this.foregroundColor = AppColors.primaryInk,
    this.fillColor = AppColors.glassFill,
    this.borderColor = AppColors.glassBorder,
    super.key,
  }) : assert(
         (icon != null ? 1 : 0) +
                 (iconAsset != null ? 1 : 0) +
                 (iconWidget != null ? 1 : 0) ==
             1,
         'Provide exactly one of icon, iconAsset or iconWidget.',
       );

  final IconData? icon;
  final String? iconAsset;

  /// A ready-made icon widget (e.g. `AppFavoriteIcon`) for glyphs that
  /// aren't a plain `Icon`/asset — carries its own color/size already.
  final Widget? iconWidget;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double dimension;
  final double iconSize;
  final Color foregroundColor;
  final Color fillColor;

  /// Fallback-path border only (Android, or iOS with the setting off) —
  /// real glass draws its own.
  final Color borderColor;

  bool _useRealGlass(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS &&
      AppGlassSettings.enabled;

  Widget _icon({required bool themed}) {
    if (iconWidget != null) return iconWidget!;
    if (iconAsset != null) {
      return AppAssetIcon(iconAsset!, size: iconSize, color: foregroundColor);
    }
    // A bare Icon(icon) (no explicit color) lets GlassIconButton apply its
    // own adaptive IconTheme (see brightnessResolver in main.dart).
    return themed ? Icon(icon) : Icon(icon, color: foregroundColor);
  }

  @override
  Widget build(BuildContext context) {
    if (_useRealGlass(context)) {
      return GlassIconButton(
        icon: _icon(themed: true),
        onPressed: onPressed,
        size: dimension,
        iconSize: iconSize,
        semanticLabel: semanticLabel,
      );
    }
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
            borderColor: borderColor,
            contentColor: foregroundColor,
            child: IconButton(
              onPressed: onPressed,
              icon: _icon(themed: false),
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
    final useGlass =
        Theme.of(context).platform == TargetPlatform.iOS &&
        AppGlassSettings.enabled;
    if (!useGlass) {
      // Android always lands here; iOS does too with the "Жидкое стекло"
      // setting off — same plain button either way, per product decision.
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
        child: GlassButton.custom(
          onTap: onPressed ?? () {},
          enabled: enabled,
          width: double.infinity,
          height: height,
          shape: const LiquidRoundedRectangle(borderRadius: AppRadii.capsule),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryInk.withValues(alpha: enabled ? 1 : 0.44),
            ),
          ),
        ),
      ),
    );
  }
}
