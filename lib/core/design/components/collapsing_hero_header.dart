import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Progress helpers for pinned collapsing hero headers.
///
/// Prefer [Transform] / [Opacity] driven by [of] — avoid animating layout
/// extents of child widgets so content does not jump while scrolling.
abstract final class CollapseProgress {
  static double of(double shrinkOffset, double maxExtent, double minExtent) {
    final range = maxExtent - minExtent;
    if (range <= 0) {
      return 1;
    }
    return (shrinkOffset / range).clamp(0.0, 1.0);
  }

  /// 1 → 0 as [t] moves through [[start], [end]].
  static double fadeOut(double t, {double start = 0.0, double end = 0.55}) {
    if (t <= start) {
      return 1;
    }
    if (t >= end) {
      return 0;
    }
    return 1 - ((t - start) / (end - start));
  }

  /// 0 → 1 as [t] moves through [[start], [end]].
  static double fadeIn(double t, {double start = 0.45, double end = 0.95}) {
    if (t <= start) {
      return 0;
    }
    if (t >= end) {
      return 1;
    }
    return (t - start) / (end - start);
  }
}

typedef CollapsingHeroBuilder =
    Widget Function(
      BuildContext context,
      double t,
      double shrinkOffset,
      double currentExtent,
    );

/// Media hero that collapses with scroll via opacity / transform only.
///
/// Prefer [pinned] = false when the next sliver overlaps the hero (rounded
/// sheet / rank card): pinned headers paint above following content and break
/// that layering. Use pinned only when the collapsed bar must stay on top.
class CollapsingHeroSliver extends StatelessWidget {
  const CollapsingHeroSliver({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.builder,
    this.parallaxFactor = 0.35,
    this.collapsedColor = AppColors.elevatedSurface,
    this.background,
    this.pinned = true,
    super.key,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final CollapsingHeroBuilder builder;
  final double parallaxFactor;
  final Color collapsedColor;
  final bool pinned;

  /// Optional media layer drawn behind overlays with parallax + fade.
  ///
  /// Prefer putting interactive media (e.g. [PageView]) here and keeping
  /// [builder] overlays sparse so empty areas pass hit tests through.
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: pinned,
      delegate: _CollapsingHeroDelegate(
        expandedHeight: expandedHeight,
        collapsedHeight: collapsedHeight,
        builder: builder,
        parallaxFactor: parallaxFactor,
        collapsedColor: collapsedColor,
        background: background,
      ),
    );
  }
}

class _CollapsingHeroDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingHeroDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.builder,
    required this.parallaxFactor,
    required this.collapsedColor,
    required this.background,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final CollapsingHeroBuilder builder;
  final double parallaxFactor;
  final Color collapsedColor;
  final Widget? background;

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final currentExtent = (maxExtent - shrinkOffset).clamp(
      minExtent,
      maxExtent,
    );
    final t = CollapseProgress.of(shrinkOffset, maxExtent, minExtent);
    final mediaFade = CollapseProgress.fadeOut(t, start: 0.15, end: 0.85);
    final barFade = CollapseProgress.fadeIn(t, start: 0.35, end: 0.9);

    // Soft-clamp parallax so the media does not leap above the safe area.
    final parallaxY = -math.min(
      shrinkOffset * parallaxFactor,
      (maxExtent - minExtent) * parallaxFactor,
    );

    return SizedBox(
      height: currentExtent,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (background != null)
              Opacity(
                opacity: mediaFade,
                child: Transform.translate(
                  offset: Offset(0, parallaxY),
                  child: SizedBox(
                    height: maxExtent,
                    width: double.infinity,
                    child: background,
                  ),
                ),
              ),
            IgnorePointer(
              ignoring: barFade < 0.05,
              child: Opacity(
                opacity: barFade,
                child: ColoredBox(color: collapsedColor),
              ),
            ),
            builder(context, t, shrinkOffset, currentExtent),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingHeroDelegate oldDelegate) {
    return expandedHeight != oldDelegate.expandedHeight ||
        collapsedHeight != oldDelegate.collapsedHeight ||
        parallaxFactor != oldDelegate.parallaxFactor ||
        collapsedColor != oldDelegate.collapsedColor ||
        background != oldDelegate.background ||
        builder != oldDelegate.builder;
  }
}

/// Circle action for expanded (glass-on-photo) and collapsed (ink-on-bar) states.
class CollapsingHeroAction extends StatelessWidget {
  const CollapsingHeroAction({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.onPhoto = true,
    this.dimension = 44,
    super.key,
  }) : assert((icon == null) != (iconAsset == null));

  final String semanticLabel;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? iconAsset;
  final bool onPhoto;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final fg = onPhoto ? Colors.white : AppColors.primaryInk;
    final child = iconAsset != null
        ? AppAssetIcon(iconAsset!, size: 22, color: fg)
        : Icon(icon, size: 22, color: fg);

    if (onPhoto) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: AppGlassCircle(
          dimension: dimension,
          blur: 10,
          fillColor: Colors.black.withValues(alpha: 0.26),
          borderColor: Colors.white.withValues(alpha: 0.22),
          contentColor: Colors.white,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: dimension,
        child: Material(
          color: AppColors.controlSurface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Convenience: fade (+ optional scale) a layer without changing layout size.
class CollapseLayer extends StatelessWidget {
  const CollapseLayer({
    required this.visibility,
    required this.child,
    this.scaleAlignment = Alignment.center,
    this.translate = Offset.zero,
    this.ignorePointersWhenHidden = true,
    this.scale = true,
    super.key,
  });

  final double visibility;
  final Widget child;
  final Alignment scaleAlignment;
  final Offset translate;
  final bool ignorePointersWhenHidden;

  /// When false, only opacity / translate are applied (avoids “drifting up”
  /// while a pinned hero collapses).
  final bool scale;

  @override
  Widget build(BuildContext context) {
    final v = visibility.clamp(0.0, 1.0);
    Widget content = child;
    if (scale) {
      content = Transform.scale(
        alignment: scaleAlignment,
        scale: 0.82 + 0.18 * v,
        child: content,
      );
    }
    if (translate != Offset.zero) {
      content = Transform.translate(offset: translate, child: content);
    }
    return IgnorePointer(
      ignoring: ignorePointersWhenHidden && v < 0.05,
      child: Opacity(opacity: v, child: content),
    );
  }
}
