import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/flat_hats.dart';

export 'package:tourism_mobile/features/companions/presentation/flat/flat_hats.dart'
    show BeanHat;

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

enum BeanShape { bean, round, pear, tall, bear }

enum BeanPattern { plain, belly, spots, stripes }

enum BeanExtra { none, glasses, scarf, backpack }

/// Everything that makes one person's bean their own: shape, markings,
/// what it wears. Derived from the person's id, so it never changes.
class BeanLook {
  const BeanLook({
    this.shape = BeanShape.bean,
    this.pattern = BeanPattern.plain,
    this.extra = BeanExtra.none,
    this.accessory,
  });

  final BeanShape shape;
  final BeanPattern pattern;
  final BeanExtra extra;
  final BeanHat? accessory;

  /// [hat] is the person's chosen hat (its slug); without it, the hat the
  /// account was given.
  factory BeanLook.forUser(String userId, {String? hat}) {
    var hash = 11;
    for (final unit in userId.codeUnits) {
      hash = (hash * 131 + unit) & 0x7fffffff;
    }
    int pick(int salt, int count) =>
        ((hash ~/ salt) ^ (hash * salt)).abs() % count;
    return BeanLook(
      shape: BeanShape.values[pick(3, BeanShape.values.length)],
      pattern: BeanPattern.values[pick(7, BeanPattern.values.length)],
      extra: BeanExtra.values[pick(13, BeanExtra.values.length)],
      accessory: BeanHat.fromSlug(hat) ?? BeanHat.forUser(userId),
    );
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
    this.accessory,
    this.breath = 0,
    this.wave = 0,
    this.step = 0,
    this.mouthOpen = false,
    this.toast = 0,
    this.flutter = 0,
    this.look,
  });

  /// Shape, markings and what it wears; a plain bean without it.
  final BeanLook? look;

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
  final BeanHat? accessory;

  /// Breathing, -1..1: the body squashes and stretches a little.
  final double breath;

  /// The free arm raised, 0 down to 1 waving high.
  final double wave;

  /// Walking, -1..1: which foot is forward.
  final double step;

  /// A round «о!» mouth: setting off, arriving.
  final bool mouthOpen;

  /// How golden the marshmallow is, 0 white to 1 toasted.
  final double toast;

  /// The leader's pennant flutter, any phase.
  final double flutter;
}

/// A bean of [height] standing with its feet at [feet].
///
/// Built from flat shapes only: a rounded body with a darker belly band,
/// stubby arms and feet, big eyes with a shine, pink cheeks, a smile and
/// something on the head.
void paintBean(
  Canvas canvas,
  Offset feet,
  double height,
  Color color,
  BeanPose pose,
) {
  final alpha = pose.dim ? 0.38 : 1.0;
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  final dark = Color.lerp(color, Colors.black, 0.22)!;
  final look = pose.look ?? const BeanLook();
  final squash = 1 + pose.breath * 0.035;
  final (shapeW, shapeH) = switch (look.shape) {
    BeanShape.bean => (0.6, 0.86),
    BeanShape.round => (0.76, 0.74),
    BeanShape.pear => (0.68, 0.84),
    BeanShape.tall => (0.48, 0.94),
    BeanShape.bear => (0.64, 0.8),
  };
  final bodyH = height * shapeH * squash;
  final width = height * shapeW / math.sqrt(squash);
  final lift = pose.bob * height;
  final legH = height * 0.12;
  final bodyBottom = feet.dy - legH * 0.55 - lift;
  final body = Rect.fromLTWH(
    feet.dx - width / 2,
    bodyBottom - bodyH,
    width,
    bodyH,
  );
  final bodyPath = _bodyPath(look.shape, body);

  // Shadow stays on the ground while the bean hops.
  canvas.drawOval(
    Rect.fromCenter(
      center: feet.translate(0, 1),
      width: width * (1.05 - pose.bob * 0.9),
      height: height * 0.09,
    ),
    fill(const Color(0x33000000)),
  );

  // Feet: two dark ovals, stepping when walking.
  for (final side in const [-1.0, 1.0]) {
    final forward = pose.step * side;
    final footLift = forward > 0 ? forward * height * 0.06 : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            feet.dx + side * width * 0.2 + forward * width * 0.12,
            feet.dy - legH * 0.3 - lift - footLift,
          ),
          width: width * 0.32,
          height: legH * 0.75,
        ),
        Radius.circular(legH * 0.4),
      ),
      fill(dark),
    );
  }

  final dir = pose.stickToRight ? 1.0 : -1.0;
  final shoulderY = body.top + bodyH * 0.55;

  // The arm holding the stick, or resting, on the fire side.
  final holdHand = Offset(
    body.center.dx + dir * width * 0.52,
    shoulderY + bodyH * (pose.ready ? 0.02 : 0.12),
  );
  if (pose.ready) {
    final tip = holdHand.translate(dir * height * 0.6, -height * 0.2);
    canvas.drawLine(
      holdHand,
      tip,
      fill(FlatPalette.logDark)
        ..strokeWidth = height * 0.045
        ..strokeCap = StrokeCap.round,
    );
    final puff = Color.lerp(
      FlatPalette.paper,
      const Color(0xFFC98B4F),
      pose.toast.clamp(0.0, 1.0),
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: tip,
          width: height * 0.15,
          height: height * 0.13,
        ),
        Radius.circular(height * 0.045),
      ),
      fill(puff),
    );
  }
  canvas.drawLine(
    Offset(body.center.dx + dir * width * 0.38, shoulderY),
    holdHand,
    fill(color)
      ..strokeWidth = height * 0.085
      ..strokeCap = StrokeCap.round,
  );

  // The other arm hangs down-out at rest and swings up-out to wave.
  final shoulder = Offset(body.center.dx - dir * width * 0.44, shoulderY);
  final arm = width * 0.4 + height * 0.08;
  final theta = 1.25 + (-1.0 - 1.25) * pose.wave.clamp(0.0, 1.0);
  final hand = shoulder.translate(
    -dir * arm * math.cos(theta),
    arm * math.sin(theta),
  );
  void freeArm(Canvas c) => c.drawLine(
    shoulder,
    hand,
    fill(color)
      ..strokeWidth = height * 0.085
      ..strokeCap = StrokeCap.round,
  );
  // A hanging arm sits behind the body, a waving one in front of it.
  if (pose.wave <= 0.15) freeArm(canvas);

  // Body with a darker belly band: shape without an outline.
  if (look.extra == BeanExtra.backpack) {
    // A backpack peeks out behind, on the side away from the fire.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.center.dx - dir * width * 0.5 - width * 0.17,
          body.top + bodyH * 0.4,
          width * 0.34,
          bodyH * 0.38,
        ),
        Radius.circular(width * 0.12),
      ),
      fill(const Color(0xFF8A5A33)),
    );
  }
  if (look.shape == BeanShape.bear) {
    for (final side in const [-1.0, 1.0]) {
      final ear = Offset(
        body.center.dx + side * width * 0.32,
        body.top + width * 0.06,
      );
      canvas.drawCircle(ear, width * 0.16, fill(color));
      canvas.drawCircle(ear, width * 0.08, fill(dark));
    }
  }
  canvas.drawPath(bodyPath, fill(color));
  canvas.save();
  canvas.clipPath(bodyPath);
  canvas.drawRect(
    Rect.fromLTWH(body.left, body.bottom - bodyH * 0.18, width, bodyH * 0.18),
    fill(dark),
  );
  // A light patch on the side catches the light.
  canvas.drawOval(
    Rect.fromLTWH(
      body.left + width * 0.12,
      body.top + bodyH * 0.12,
      width * 0.16,
      bodyH * 0.3,
    ),
    fill(Colors.white.withValues(alpha: 0.18)),
  );
  switch (look.pattern) {
    case BeanPattern.plain:
      break;
    case BeanPattern.belly:
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(body.center.dx, body.top + bodyH * 0.72),
          width: width * 0.62,
          height: bodyH * 0.38,
        ),
        fill(Color.lerp(color, Colors.white, 0.45)!),
      );
    case BeanPattern.spots:
      for (final (dx, dy, rr) in const [
        (-0.28, 0.62, 0.09),
        (0.24, 0.7, 0.07),
        (0.05, 0.84, 0.06),
        (0.32, 0.5, 0.05),
      ]) {
        canvas.drawCircle(
          Offset(body.center.dx + dx * width, body.top + dy * bodyH),
          rr * width * 1.4,
          fill(dark),
        );
      }
    case BeanPattern.stripes:
      for (final y in const [0.6, 0.72]) {
        canvas.drawRect(
          Rect.fromLTWH(body.left, body.top + y * bodyH, width, bodyH * 0.055),
          fill(Color.lerp(color, Colors.white, 0.4)!),
        );
      }
  }
  if (look.extra == BeanExtra.backpack) {
    // The strap across the chest.
    canvas.drawLine(
      Offset(body.center.dx - dir * width * 0.5, body.top + bodyH * 0.42),
      Offset(body.center.dx + dir * width * 0.1, body.top + bodyH * 0.8),
      fill(const Color(0xFF6C4426))
        ..strokeWidth = width * 0.08
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.restore();

  if (pose.wave > 0.15) freeArm(canvas);

  // Eyes with pupils and a shine, looking where the bean looks.
  final eyeY = body.top + bodyH * 0.34;
  final eyeGap = width * 0.21;
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
          ..strokeWidth = height * 0.032
          ..strokeCap = StrokeCap.round,
      );
      continue;
    }
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: width * 0.28, height: bodyH * 0.24),
      fill(FlatPalette.white),
    );
    final pupil = eye.translate(pose.lookX * width * 0.05, height * 0.02);
    canvas.drawCircle(pupil, height * 0.048, fill(FlatPalette.ink));
    canvas.drawCircle(
      pupil.translate(-height * 0.016, -height * 0.018),
      height * 0.016,
      fill(FlatPalette.white),
    );
  }
  // Pink cheeks.
  for (final side in const [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          body.center.dx + side * width * 0.33,
          eyeY + bodyH * 0.17,
        ),
        width: width * 0.17,
        height: bodyH * 0.07,
      ),
      fill(const Color(0x66FF6F91)),
    );
  }
  final mouthY = eyeY + bodyH * 0.2;
  if (pose.mouthOpen) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(body.center.dx, mouthY + bodyH * 0.03),
        width: width * 0.16,
        height: bodyH * 0.11,
      ),
      fill(FlatPalette.ink),
    );
  } else {
    final mouth = Path()
      ..moveTo(body.center.dx - width * 0.12, mouthY)
      ..quadraticBezierTo(
        body.center.dx,
        mouthY + bodyH * (pose.happy ? 0.12 : 0.08),
        body.center.dx + width * 0.12,
        mouthY,
      );
    canvas.drawPath(
      mouth,
      fill(FlatPalette.ink)
        ..style = PaintingStyle.stroke
        ..strokeWidth = height * 0.03
        ..strokeCap = StrokeCap.round,
    );
  }

  if (look.extra == BeanExtra.glasses && !pose.blink && !pose.happy) {
    final rim = fill(FlatPalette.ink)
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.022;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(body.center.dx + side * eyeGap, eyeY),
        width * 0.17,
        rim,
      );
    }
    canvas.drawLine(
      Offset(body.center.dx - eyeGap + width * 0.17, eyeY),
      Offset(body.center.dx + eyeGap - width * 0.17, eyeY),
      rim,
    );
  }
  if (look.extra == BeanExtra.scarf) {
    final scarfY = mouthY + bodyH * 0.11;
    final scarf = fill(
      FlatPalette.beans[(color.toARGB32() ~/ 7) % FlatPalette.beans.length] ==
              color
          ? FlatPalette.flameOuter
          : FlatPalette.beans[(color.toARGB32() ~/ 7) %
                FlatPalette.beans.length],
    );
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawRect(
      Rect.fromLTWH(body.left, scarfY, width, bodyH * 0.1),
      scarf,
    );
    canvas.restore();
    // The loose end flutters behind.
    final end = Offset(
      body.center.dx - dir * width * 0.36,
      scarfY + bodyH * 0.05,
    );
    final flap = math.sin(pose.flutter * math.pi * 2) * height * 0.03;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy - bodyH * 0.04)
        ..lineTo(end.dx - dir * width * 0.32, end.dy + bodyH * 0.12 + flap)
        ..lineTo(end.dx - dir * width * 0.18, end.dy + bodyH * 0.16 + flap)
        ..lineTo(end.dx + dir * width * 0.04, end.dy + bodyH * 0.05)
        ..close(),
      scarf,
    );
  }
  final hat = look.accessory ?? pose.accessory;
  if (hat != null) {
    // The hat keeps its size while the body breathes: sized by the body
    // at rest and only riding up and down with its top, or it pulses.
    final restWidth = height * shapeW;
    paintHat(
      canvas,
      hat,
      Rect.fromLTWH(
        body.center.dx - restWidth / 2,
        body.top,
        restWidth,
        height * shapeH,
      ),
      bodyColor: color,
      alpha: alpha,
      facingRight: pose.stickToRight,
      sway: pose.breath * 0.5,
    );
  }

  if (pose.organizer) {
    // The leader carries a pennant that flutters.
    final pole = Offset(body.right - width * 0.04, body.top + bodyH * 0.18);
    final top = pole.translate(0, -height * 0.5);
    canvas.drawLine(
      pole,
      top,
      fill(FlatPalette.ink)
        ..strokeWidth = height * 0.028
        ..strokeCap = StrokeCap.round,
    );
    final wobble = math.sin(pose.flutter * math.pi * 2) * height * 0.03;
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(
        top.dx + height * 0.14,
        top.dy + wobble,
        top.dx + height * 0.28,
        top.dy + height * 0.07 - wobble * 0.5,
      )
      ..lineTo(top.dx, top.dy + height * 0.16)
      ..close();
    canvas.drawPath(flag, fill(FlatPalette.flameOuter));
  }
}

Path _bodyPath(BeanShape shape, Rect body) {
  final w = body.width;
  final h = body.height;
  switch (shape) {
    case BeanShape.bean:
    case BeanShape.tall:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(w / 2)));
    case BeanShape.round:
      return Path()..addOval(body);
    case BeanShape.bear:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(w * 0.3)));
    case BeanShape.pear:
      // Narrow shoulders, a wide bottom.
      return Path()
        ..moveTo(body.center.dx, body.top)
        ..cubicTo(
          body.left + w * 0.12,
          body.top,
          body.left + w * 0.14,
          body.top + h * 0.42,
          body.left,
          body.top + h * 0.72,
        )
        ..cubicTo(
          body.left - w * 0.02,
          body.bottom + h * 0.02,
          body.right + w * 0.02,
          body.bottom + h * 0.02,
          body.right,
          body.top + h * 0.72,
        )
        ..cubicTo(
          body.right - w * 0.14,
          body.top + h * 0.42,
          body.right - w * 0.12,
          body.top,
          body.center.dx,
          body.top,
        )
        ..close();
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
