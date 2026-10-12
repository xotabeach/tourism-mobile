import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_radii.dart';

const _base = Color(0xFFE3E3E3);
const _highlight = Color(0xFFF4F4F4);

/// Neutral loading surface that preserves layout without showing fake data.
///
/// Inside an [AppShimmer] it paints the moving highlight itself, placed by
/// where it sits in the shimmer, so neighbouring blocks share one sweep.
/// Nothing else under the shimmer is recoloured: a white card stays white
/// around its grey blocks (FRONTEND-71). The old shimmer masked everything
/// it covered and turned whole cards and pages into one grey slab.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    required this.width,
    required this.height,
    this.borderRadius = AppRadii.card,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.state;
    final Widget block;
    if (scope == null) {
      block = DecoratedBox(
        decoration: BoxDecoration(
          color: _base,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      );
    } else {
      block = AnimatedBuilder(
        animation: scope.animation,
        builder: (context, _) => CustomPaint(
          painter: _SkeletonPainter(
            slide: scope.animation.value,
            // Read while painting, when both boxes have their layout.
            shimmerRect: () => scope.rectOf(context),
            shape: shape,
            radius: borderRadius,
          ),
        ),
      );
    }
    return SizedBox(width: width, height: height, child: block);
  }
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter({
    required this.slide,
    required this.shimmerRect,
    required this.shape,
    required this.radius,
  });

  final double slide;

  /// The whole shimmer area in this block's own coordinates; null when it
  /// cannot be measured, and the block is drawn plain.
  final Rect? Function() shimmerRect;
  final BoxShape shape;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..color = _base;
    if (shimmerRect() case final area?) {
      final x = slide * 2.8 - 1.4;
      paint.shader = LinearGradient(
        begin: Alignment(x - 1, 0),
        end: Alignment(x + 1, 0),
        colors: const [_base, _highlight, _base],
        stops: const [0.25, 0.5, 0.75],
      ).createShader(area);
    }
    if (shape == BoxShape.circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) =>
      slide != oldDelegate.slide ||
      shape != oldDelegate.shape ||
      radius != oldDelegate.radius;
}

/// Sweeps one highlight across every [AppSkeleton] below it.
class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Animation<double> get animation => _controller;

  /// The shimmer's own box seen from the block at [context].
  Rect? rectOf(BuildContext context) {
    if (!mounted || !context.mounted) return null;
    final area = this.context.findRenderObject();
    final block = context.findRenderObject();
    if (area is! RenderBox ||
        block is! RenderBox ||
        !area.hasSize ||
        !block.hasSize ||
        !area.attached ||
        !block.attached) {
      return null;
    }
    final origin = block.globalToLocal(area.localToGlobal(Offset.zero));
    return origin & area.size;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerScope(state: this, child: widget.child);
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.state, required super.child});

  final _AppShimmerState state;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) => state != oldWidget.state;
}
