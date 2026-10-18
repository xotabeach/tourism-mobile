import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// A character's round head with the designer's face (FRONTEND-88): the
/// avatar of a member in the group's lists and the marker on the mountain.
///
/// Laid out as on the mockup: the eyes span 40% of the circle and start at
/// 31% of its height; the mouth sits under them as drawn.
class BeanHead extends StatelessWidget {
  const BeanHead({required this.kind, required this.size, super.key});

  final BeanKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: BeanHeadPainter(kind)),
  );
}

class BeanHeadPainter extends CustomPainter {
  const BeanHeadPainter(this.kind);

  final BeanKind kind;

  @override
  void paint(Canvas canvas, Size size) => paintBeanHead(
    canvas,
    Offset(size.width / 2, size.height / 2),
    size.width,
    kind,
  );

  @override
  bool shouldRepaint(covariant BeanHeadPainter old) => old.kind != kind;
}

/// Paints a head of [diameter] centred on [center].
void paintBeanHead(
  Canvas canvas,
  Offset center,
  double diameter,
  BeanKind kind, {
  double ring = 0,
}) {
  final art = kind.art;
  final data = art.data;
  final r = diameter / 2;
  final circle = Rect.fromCircle(center: center, radius: r);
  if (ring > 0) {
    canvas.drawCircle(center, r + ring, Paint()..color = Colors.white);
  }
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [data.bodyTop, data.bodyBottom],
      ).createShader(circle),
  );
  final eyes = art.eyeLeft.getBounds().expandToInclude(
    art.eyeRight.getBounds(),
  );
  final scale = diameter * 0.4 / eyes.width;
  canvas.save();
  canvas.translate(
    circle.left + diameter * 0.297,
    circle.top + diameter * 0.31,
  );
  canvas.scale(scale);
  canvas.translate(-eyes.left, -eyes.top);
  final ink = Paint()..color = Colors.black;
  final white = Paint()..color = Colors.white;
  canvas.drawPath(
    Path.combine(PathOperation.union, art.eyeLeft, art.shineLeft),
    ink,
  );
  canvas.drawPath(
    Path.combine(PathOperation.union, art.eyeRight, art.shineRight),
    ink,
  );
  canvas.drawPath(art.shineLeft, white);
  canvas.drawPath(art.shineRight, white);
  canvas.drawPath(art.mouth, white);
  canvas.restore();
}
