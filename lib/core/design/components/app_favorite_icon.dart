import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';

/// The supplied design heart for both favorite states.
///
/// The original asset remains on top in both states. Selection only adds a
/// fill underneath it, so toggling never swaps the heart for another shape.
class AppFavoriteIcon extends StatelessWidget {
  const AppFavoriteIcon({
    required this.selected,
    this.size = 24,
    this.color = Colors.white,
    super.key,
  });

  final bool selected;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (selected)
            CustomPaint(painter: _FavoriteHeartFillPainter(color: color)),
          AppAssetIcon(AppIconography.heart, size: size, color: color),
        ],
      ),
    );
  }
}

class _FavoriteHeartFillPainter extends CustomPainter {
  const _FavoriteHeartFillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 32;
    final scaleY = size.height / 32;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Centre-line geometry from assets/icons/source/heart.svg. The rasterized
    // outline above masks the edge, leaving the original notch and inner line
    // untouched while the body becomes solid.
    final heart = Path()
      ..moveTo(16, 7.33)
      ..cubicTo(12.8, 4.18, 9.58, 3.85, 7.08, 4.99)
      ..cubicTo(4.5, 6.17, 2.67, 8.94, 2.67, 12.18)
      ..cubicTo(2.67, 18.12, 7.19, 21.46, 11.95, 25.21)
      ..cubicTo(13.29, 26.27, 14.67, 27.33, 16, 27.33)
      ..cubicTo(17.33, 27.33, 18.71, 26.27, 20.05, 25.21)
      ..cubicTo(24.81, 21.46, 29.33, 18.12, 29.33, 12.18)
      ..cubicTo(29.33, 8.94, 27.5, 6.17, 24.92, 4.99)
      ..cubicTo(22.42, 3.85, 19.2, 4.18, 16, 7.33)
      ..close();

    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FavoriteHeartFillPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
