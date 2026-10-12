import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The companions' flat world (FRONTEND-63, 64): bold fills, no outlines,
/// no gradients, round friendly shapes. Everyone in a group is a «bean»
/// of their own colour, the same colour on every screen.
abstract final class FlatPalette {
  static const night = Color(0xFF1D2B53);
  static const nightLow = Color(0xFF26386B);
  static const star = Color(0xFFFFF1C1);
  static const moon = Color(0xFFFFE9A8);
  static const hillFar = Color(0xFF2E4A7D);
  static const hillNear = Color(0xFF2F6B5E);
  static const ground = Color(0xFF3E8A5F);
  static const groundDark = Color(0xFF327450);
  static const log = Color(0xFF8A5A33);
  static const logDark = Color(0xFF6C4426);
  static const flameOuter = Color(0xFFFF6B35);
  static const flameMid = Color(0xFFFFA62B);
  static const flameCore = Color(0xFFFFE66D);
  static const firelight = Color(0xFF5BA56B);
  static const rope = Color(0xFFC98B4F);
  static const ropeDark = Color(0xFFA36A36);
  static const trail = Color(0xFF34C759);
  static const paper = Color(0xFFFFF6E5);
  static const ink = Color(0xFF1B1B2F);
  static const white = Color(0xFFFFFFFF);

  static const beans = [
    Color(0xFFF25C54),
    Color(0xFF4CC3D9),
    Color(0xFFFFC145),
    Color(0xFF7AC74F),
    Color(0xFFB388EB),
    Color(0xFFFF8FB1),
    Color(0xFFF79D65),
    Color(0xFF5B8DEF),
  ];

  /// The same colour for the same person, wherever they are drawn.
  static Color beanFor(String userId) {
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return beans[hash % beans.length];
  }
}

/// How a bean looks this frame.
class BeanPose {
  const BeanPose({
    this.bob = 0,
    this.blink = false,
    this.lookX = 0,
    this.ready = false,
    this.organizer = false,
    this.dim = false,
    this.happy = false,
    this.stickToRight = true,
  });

  /// Vertical hop, in body heights.
  final double bob;
  final bool blink;

  /// Where the eyes look, -1 left to 1 right.
  final double lookX;

  /// Holds a marshmallow over the fire: «готов».
  final bool ready;

  /// Wears the leader's little flag.
  final bool organizer;

  /// Not started yet: drawn faded, like a ghost of themselves.
  final bool dim;

  /// Closed happy eyes, at the finish.
  final bool happy;
  final bool stickToRight;
}

/// A bean of [height] standing with its feet at [feet].
void paintBean(
  Canvas canvas,
  Offset feet,
  double height,
  Color color,
  BeanPose pose,
) {
  final width = height * 0.66;
  final lift = pose.bob * height;
  final body = Rect.fromCenter(
    center: feet.translate(0, -height / 2 - lift),
    width: width,
    height: height,
  );
  final alpha = pose.dim ? 0.38 : 1.0;
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);

  // Shadow on the ground stays put while the bean hops.
  canvas.drawOval(
    Rect.fromCenter(
      center: feet.translate(0, 1),
      width: width * (0.9 - pose.bob * 0.8),
      height: height * 0.1,
    ),
    fill(const Color(0x33000000)),
  );

  if (pose.ready) {
    // A stick toward the fire with a toasted marshmallow.
    final dir = pose.stickToRight ? 1.0 : -1.0;
    final hand = body.center.translate(dir * width * 0.35, height * 0.08);
    final tip = hand.translate(dir * height * 0.62, -height * 0.18);
    canvas.drawLine(
      hand,
      tip,
      fill(FlatPalette.logDark)
        ..strokeWidth = height * 0.05
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: tip,
          width: height * 0.16,
          height: height * 0.13,
        ),
        Radius.circular(height * 0.04),
      ),
      fill(FlatPalette.paper),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: tip.translate(0, height * 0.035),
          width: height * 0.16,
          height: height * 0.06,
        ),
        Radius.circular(height * 0.03),
      ),
      fill(const Color(0xFFD9A066)),
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(width / 2)),
    fill(color),
  );
  // A darker belly band gives the bean its shape without an outline.
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(body, Radius.circular(width / 2)));
  canvas.drawRect(
    Rect.fromLTWH(body.left, body.bottom - height * 0.16, width, height * 0.16),
    fill(Color.lerp(color, Colors.black, 0.18)!),
  );
  canvas.restore();

  // Eyes: big white ovals, pupils looking where the bean looks.
  final eyeY = body.top + height * 0.3;
  final eyeGap = width * 0.2;
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(body.center.dx + side * eyeGap, eyeY);
    if (pose.blink || pose.happy) {
      final path = Path()
        ..moveTo(eye.dx - width * 0.11, eyeY)
        ..quadraticBezierTo(
          eye.dx,
          eyeY + (pose.happy ? -height * 0.07 : height * 0.02),
          eye.dx + width * 0.11,
          eyeY,
        );
      canvas.drawPath(
        path,
        fill(FlatPalette.ink)
          ..style = PaintingStyle.stroke
          ..strokeWidth = height * 0.035
          ..strokeCap = StrokeCap.round,
      );
      continue;
    }
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: width * 0.26, height: height * 0.2),
      fill(FlatPalette.white),
    );
    canvas.drawCircle(
      eye.translate(pose.lookX * width * 0.05, height * 0.02),
      height * 0.045,
      fill(FlatPalette.ink),
    );
  }
  // A small smile.
  final mouth = Path()
    ..moveTo(body.center.dx - width * 0.12, eyeY + height * 0.17)
    ..quadraticBezierTo(
      body.center.dx,
      eyeY + height * (pose.happy ? 0.29 : 0.24),
      body.center.dx + width * 0.12,
      eyeY + height * 0.17,
    );
  canvas.drawPath(
    mouth,
    fill(FlatPalette.ink)
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.03
      ..strokeCap = StrokeCap.round,
  );

  if (pose.organizer) {
    // The leader carries a little pennant on a pole.
    final pole = Offset(body.left + width * 0.08, body.top + height * 0.05);
    canvas.drawLine(
      pole,
      pole.translate(0, -height * 0.42),
      fill(FlatPalette.ink)
        ..strokeWidth = height * 0.03
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(pole.dx, pole.dy - height * 0.42)
      ..lineTo(pole.dx + height * 0.26, pole.dy - height * 0.34)
      ..lineTo(pole.dx, pole.dy - height * 0.26)
      ..close();
    canvas.drawPath(flag, fill(FlatPalette.flameOuter));
  }
}

/// A name label under a bean, drawn on the canvas.
void paintLabel(
  Canvas canvas,
  Offset topCenter,
  String text, {
  required double size,
  Color color = FlatPalette.white,
  double maxWidth = 90,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rubik',
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, topCenter.translate(-painter.width / 2, 0));
}

/// A deterministic pseudo-random in 0..1 for decorations that must not
/// jump between frames.
double seeded(int seed) {
  final x = math.sin(seed * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}
