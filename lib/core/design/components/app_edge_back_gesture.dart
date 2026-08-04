import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';

/// Cross-platform leading-edge back gesture for shell-root screens that do
/// not have a native Navigator route beneath them.
class AppEdgeBackGesture extends StatefulWidget {
  const AppEdgeBackGesture({
    required this.onBack,
    required this.child,
    super.key,
  });

  final VoidCallback onBack;
  final Widget child;

  @override
  State<AppEdgeBackGesture> createState() => _AppEdgeBackGestureState();
}

class _AppEdgeBackGestureState extends State<AppEdgeBackGesture> {
  static const _edgeWidth = 26.0;
  static const _commitDistance = 74.0;
  static const _commitVelocity = 650.0;

  double _distance = 0;
  double _startY = 160;
  bool _tracking = false;

  double get _progress => (_distance / _commitDistance).clamp(0, 1);

  void _reset() {
    if (!mounted) return;
    setState(() {
      _tracking = false;
      _distance = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final eased = Curves.easeOutCubic.transform(_progress);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final indicatorTop = (_startY - 22).clamp(12.0, viewportHeight - 56);

    return ColoredBox(
      color: AppColors.pageSurface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: _tracking || reduceMotion
                ? Duration.zero
                : AppMotion.fast,
            curve: AppMotion.standard,
            transform: Matrix4.translationValues(18 * eased, 0, 0),
            child: widget.child,
          ),
          Positioned(
            key: const ValueKey('edge-back-hit-area'),
            left: 0,
            top: 0,
            bottom: 0,
            width: _edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                setState(() {
                  _tracking = true;
                  _startY = details.localPosition.dy;
                  _distance = 0;
                });
              },
              onHorizontalDragUpdate: (details) {
                if (!_tracking) return;
                setState(() {
                  _distance = (_distance + details.delta.dx).clamp(
                    0,
                    _commitDistance * 1.25,
                  );
                });
              },
              onHorizontalDragEnd: (details) {
                final shouldPop =
                    _progress >= 1 ||
                    (details.primaryVelocity ?? 0) >= _commitVelocity;
                if (shouldPop) {
                  widget.onBack();
                }
                _reset();
              },
              onHorizontalDragCancel: _reset,
            ),
          ),
          if (_tracking && !reduceMotion)
            Positioned(
              left: -34 + 44 * eased,
              top: indicatorTop,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.35 + 0.65 * eased,
                  child: Transform.scale(
                    scale: 0.78 + 0.22 * eased,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryInk.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
