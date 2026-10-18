import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_art.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// A person's character as their avatar when they have no picture of
/// their own (FRONTEND-97): the head and hat, close up in a circle, on a
/// soft tint of the character's colour.
class BeanPortrait extends StatelessWidget {
  const BeanPortrait({required this.look, required this.size, super.key});

  final BeanLook look;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(
      child: CustomPaint(painter: BeanPortraitPainter(look)),
    ),
  );
}

class BeanPortraitPainter extends CustomPainter {
  const BeanPortraitPainter(this.look);

  final BeanLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = look.kind.art.data;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(colors.bodyTop, Colors.white, 0.8)!,
    );
    final art = look.kind.art;
    final body = art.bodyBounds;
    final w = body.width;
    final mouth = art.mouth.getBounds();
    // From room for a hat above the head to under the smile, the same for
    // everyone so faces in a list are one size; a tall hat's tip may run
    // off the circle, the body runs off its bottom.
    final top = body.top - 0.4 * w;
    final span = math.max(mouth.bottom + 0.36 * w - top, w * 1.2);
    final scale = size.width / span;
    final centre = Offset(body.center.dx, top + span / 2);
    final feet =
        Offset(size.width / 2, size.height / 2) +
        (art.data.ground - centre) * scale;
    paintBean(
      canvas,
      feet,
      beanArtBlueHeight * scale,
      look.color,
      BeanPose(look: look, armless: true),
    );
  }

  @override
  bool shouldRepaint(covariant BeanPortraitPainter oldDelegate) =>
      oldDelegate.look != look;
}
