import 'package:flutter/material.dart';

/// One heart silhouette for both favorite states.
///
/// The selected state fills the exact path used by the outlined state, so the
/// icon keeps the same size and shape when it toggles.
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
      child: CustomPaint(
        painter: _FavoriteHeartPainter(selected: selected, color: color),
      ),
    );
  }
}

class _FavoriteHeartPainter extends CustomPainter {
  const _FavoriteHeartPainter({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 32;
    final scaleY = size.height / 32;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final heart = Path()
      ..moveTo(16, 27.33)
      ..cubicTo(14.67, 27.33, 13.29, 26.27, 11.95, 25.21)
      ..cubicTo(7.19, 21.46, 2.67, 18.12, 2.67, 12.18)
      ..cubicTo(2.67, 8.94, 4.5, 6.17, 7.08, 4.99)
      ..cubicTo(9.58, 3.85, 12.8, 4.18, 16, 7.33)
      ..cubicTo(19.2, 4.18, 22.42, 3.85, 24.92, 4.99)
      ..cubicTo(27.5, 6.17, 29.33, 8.94, 29.33, 12.18)
      ..cubicTo(29.33, 18.12, 24.81, 21.46, 20.05, 25.21)
      ..cubicTo(18.71, 26.27, 17.33, 27.33, 16, 27.33)
      ..close();

    if (selected) {
      canvas.drawPath(
        heart,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FavoriteHeartPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.color != color;
  }
}
