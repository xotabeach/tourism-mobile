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

/// The designer's character (DESIGN-20, sketch 2026-10-12): a drop like a
/// map pin, round on top and narrowing to a point it stands on. Everyone
/// shares it; the proportions vary a little.
enum BeanShape { pin, pinWide, pinTall }

enum BeanPattern { plain, belly, spots, stripes }

enum BeanExtra { none, glasses, scarf, backpack }

/// Everything that makes one person's bean their own: shape, markings,
/// what it wears. Derived from the person's id, so it never changes.
class BeanLook {
  const BeanLook({
    this.shape = BeanShape.pin,
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
    BeanShape.pin => (0.62, 0.95),
    BeanShape.pinWide => (0.7, 0.9),
    BeanShape.pinTall => (0.55, 1.0),
  };
  final bodyH = height * shapeH * squash;
  final width = height * shapeW / math.sqrt(squash);
  final lift = pose.bob * height;
  final bodyBottom = feet.dy - lift;
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
      width: width * (0.7 - pose.bob * 0.5),
      height: height * 0.07,
    ),
    fill(const Color(0x33000000)),
  );

  // No feet: it stands on its point, and walks by rocking side to side.
  canvas.save();
  canvas.translate(feet.dx, feet.dy - lift);
  canvas.rotate(pose.step * 0.12);
  canvas.translate(-feet.dx, -(feet.dy - lift));

  final dir = pose.stickToRight ? 1.0 : -1.0;
  // Arms come out where the head is still wide, above the band.
  final shoulderY = body.top + bodyH * 0.46;

  // The arm holding the stick, or resting, on the fire side.
  final holdHand = Offset(
    body.center.dx + dir * width * 0.6,
    shoulderY + bodyH * (pose.ready ? 0.0 : 0.1),
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
    Offset(body.center.dx + dir * width * 0.36, shoulderY),
    holdHand,
    fill(color)
      ..strokeWidth = height * 0.085
      ..strokeCap = StrokeCap.round,
  );

  // The other arm hangs down-out at rest and swings up-out to wave.
  final shoulder = Offset(body.center.dx - dir * width * 0.4, shoulderY);
  final arm = width * 0.3 + height * 0.05;
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
  canvas.drawPath(bodyPath, fill(color));
  canvas.save();
  canvas.clipPath(bodyPath);
  // The curved line of the sketch: below it the point is another tone.
  final bandY = body.top + bodyH * 0.6;
  final lower = Path()
    ..moveTo(body.left - width * 0.1, bandY - bodyH * 0.03)
    ..quadraticBezierTo(
      body.center.dx,
      bandY + bodyH * 0.07,
      body.right + width * 0.1,
      bandY - bodyH * 0.03,
    )
    ..lineTo(body.right + width * 0.1, body.bottom + 2)
    ..lineTo(body.left - width * 0.1, body.bottom + 2)
    ..close();
  canvas.drawPath(
    lower,
    fill(
      look.pattern == BeanPattern.belly
          ? Color.lerp(color, Colors.white, 0.5)!
          : dark,
    ),
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
      // The light point is drawn with the band above.
      break;
    case BeanPattern.spots:
      for (final (dx, dy, rr) in const [
        (-0.16, 0.7, 0.07),
        (0.14, 0.76, 0.06),
        (0.0, 0.88, 0.05),
        (-0.3, 0.42, 0.05),
      ]) {
        canvas.drawCircle(
          Offset(body.center.dx + dx * width, body.top + dy * bodyH),
          rr * width * 1.4,
          fill(dark),
        );
      }
    case BeanPattern.stripes:
      for (final y in const [0.72, 0.82]) {
        canvas.drawRect(
          Rect.fromLTWH(body.left, body.top + y * bodyH, width, bodyH * 0.055),
          fill(color),
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

  // The face of the reference (owner, 2026-10-12): solid black upright
  // eyes with a white shine, and a wide white smile. No whites, no cheeks.
  final eyeY = body.top + bodyH * 0.3;
  final eyeGap = width * 0.17;
  final eyeW = width * 0.17;
  final eyeH = bodyH * 0.2;
  // The whole eye shifts a touch toward where the bean looks.
  final gaze = pose.lookX.clamp(-1.0, 1.0) * width * 0.035;
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(body.center.dx + side * eyeGap + gaze, eyeY);
    if (pose.blink || pose.happy) {
      final path = Path()
        ..moveTo(eye.dx - eyeW * 0.6, eyeY)
        ..quadraticBezierTo(
          eye.dx,
          eyeY + (pose.happy ? -eyeH * 0.45 : eyeH * 0.12),
          eye.dx + eyeW * 0.6,
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
      Rect.fromCenter(center: eye, width: eyeW, height: eyeH),
      fill(FlatPalette.ink),
    );
    canvas.drawCircle(
      eye.translate(eyeW * 0.18, -eyeH * 0.2),
      eyeW * 0.2,
      fill(FlatPalette.white),
    );
  }
  final mouthY = eyeY + bodyH * 0.17;
  if (pose.mouthOpen) {
    // «О!»: a white open mouth.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(body.center.dx + gaze, mouthY + bodyH * 0.04),
        width: width * 0.22,
        height: bodyH * 0.13,
      ),
      fill(FlatPalette.white),
    );
  } else {
    // A wide white crescent: a gently curved top, a deep round bottom.
    final half = width * (pose.happy ? 0.33 : 0.3);
    final depth = bodyH * (pose.happy ? 0.13 : 0.11);
    final cx = body.center.dx + gaze;
    canvas.drawPath(
      Path()
        ..moveTo(cx - half, mouthY)
        ..quadraticBezierTo(cx, mouthY + depth * 0.35, cx + half, mouthY)
        ..cubicTo(
          cx + half * 1.02,
          mouthY + depth * 1.2,
          cx - half * 1.02,
          mouthY + depth * 1.2,
          cx - half,
          mouthY,
        )
        ..close(),
      fill(FlatPalette.white),
    );
  }

  if (look.extra == BeanExtra.glasses && !pose.blink && !pose.happy) {
    final rim = fill(FlatPalette.ink)
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.022;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(body.center.dx + side * eyeGap, eyeY),
        width * 0.15,
        rim,
      );
    }
    canvas.drawLine(
      Offset(body.center.dx - eyeGap + width * 0.15, eyeY),
      Offset(body.center.dx + eyeGap - width * 0.15, eyeY),
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
  if (hat == null || hat == BeanHat.tuft || hat == BeanHat.headband) {
    // The little knob on top of the sketch.
    canvas.drawCircle(
      Offset(body.center.dx, body.top - height * 0.012),
      width * 0.06,
      fill(dark),
    );
  }
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
  canvas.restore();
}

Path _bodyPath(BeanShape shape, Rect body) {
  // A drop: a round head that narrows to a softly rounded point.
  final w = body.width;
  final h = body.height;
  final cx = body.center.dx;
  final r = w / 2;
  final tip = body.bottom;
  return Path()
    ..moveTo(cx, body.top)
    ..cubicTo(
      cx + r * 1.12,
      body.top,
      cx + r * 1.1,
      body.top + h * 0.52,
      cx + r * 0.22,
      tip - h * 0.04,
    )
    ..quadraticBezierTo(cx, tip + h * 0.012, cx - r * 0.22, tip - h * 0.04)
    ..cubicTo(
      cx - r * 1.1,
      body.top + h * 0.52,
      cx - r * 1.12,
      body.top,
      cx,
      body.top,
    )
    ..close();
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
