import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_radii.dart';

/// Neutral loading surface that preserves layout without showing fake data.
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
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE3E3E3),
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}

/// Adds a moving highlight to one or more [AppSkeleton] descendants.
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 2.8 - 1.4;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(slide - 1, 0),
            end: Alignment(slide + 1, 0),
            colors: const [
              Color(0xFFE1E1E1),
              Color(0xFFF4F4F4),
              Color(0xFFE1E1E1),
            ],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
