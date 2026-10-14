import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/flat_hats.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_outfits.dart';

export 'package:tourism_mobile/features/companions/presentation/flat/flat_hats.dart'
    show BeanHat;
export 'package:tourism_mobile/features/companions/presentation/flat/flat_outfits.dart'
    show BeanOutfit;

/// The companions' flat world (FRONTEND-63, 64): bold fills, no outlines,
/// round friendly shapes. Everyone in a group is a «bean», a map pin with
/// arms and legs.
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

/// The four characters of the owner's sketch (FRONTEND-79, 2026-10-15):
/// one map pin in four builds, each with its own colour. A person picks
/// one; all four are free.
enum BeanKind {
  pin('pin', 'Синий', Color(0xFF2474CF), 1, 0.74, 0.38, 0.32),
  tall('tall', 'Зелёный', Color(0xFF1EC3A6), 1.16, 0.53, 0.3, 0.24),
  small('small', 'Жёлтый', Color(0xFFF7C928), 0.68, 0.7, 0.4, 0.36),
  round('round', 'Красный', Color(0xFFDD2D2F), 1.02, 0.72, 0.46, 0.32);

  const BeanKind(
    this.slug,
    this.title,
    this.color,
    this.scale,
    this.aspect,
    this.widest,
    this.eyeAt,
  );

  /// The server's name for it.
  final String slug;
  final String title;
  final Color color;

  /// Height against the blue one: the green is taller, the yellow a kid.
  final double scale;

  /// Body width to body height.
  final double aspect;

  /// Where the body is widest, from the top, in body heights.
  final double widest;

  /// Where the eyes sit, from the top, in body heights.
  final double eyeAt;

  static BeanKind? fromSlug(String? slug) {
    for (final kind in values) {
      if (kind.slug == slug) return kind;
    }
    return null;
  }

  /// The character an account starts with until the person picks one.
  static BeanKind forUser(String userId) {
    var hash = 5;
    for (final unit in userId.codeUnits) {
      hash = (hash * 29 + unit) & 0x7fffffff;
    }
    return values[hash % values.length];
  }
}

/// Everything that makes one person's bean their own: which character,
/// what it wears on the head and on the body.
class BeanLook {
  const BeanLook({
    this.kind = BeanKind.pin,
    this.accessory,
    this.outfit = BeanOutfit.none,
  });

  final BeanKind kind;
  final BeanHat? accessory;
  final BeanOutfit outfit;

  Color get color => kind.color;

  /// [kind], [hat] and [outfit] are the person's choices (slugs); without
  /// them, what the account was given.
  factory BeanLook.forUser(
    String userId, {
    String? hat,
    String? kind,
    String? outfit,
  }) => BeanLook(
    kind: BeanKind.fromSlug(kind) ?? BeanKind.forUser(userId),
    accessory: BeanHat.fromSlug(hat) ?? BeanHat.forUser(userId),
    outfit: BeanOutfit.fromSlug(outfit) ?? BeanOutfit.none,
  );
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

  /// Character and clothes; a plain blue bean without it.
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

/// How tall a bean of [kind] stands when the blue one is [height].
double beanHeight(BeanKind kind, double height) => height * kind.scale;

/// A bean whose blue build is [height] tall, standing with its feet at
/// [feet]. Other builds are taller or shorter by their [BeanKind.scale].
///
/// The owner's sketch: a pin with a soft top-to-bottom shade and a light
/// streak on the top left, thin arms and legs a shade darker, small feet
/// turned out, solid black eyes with a shine and a white smile.
void paintBean(
  Canvas canvas,
  Offset feet,
  double height,
  Color color,
  BeanPose pose,
) {
  final alpha = pose.dim ? 0.38 : 1.0;
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  final look = pose.look ?? const BeanLook();
  final kind = look.kind;
  final total = beanHeight(kind, height);
  final limb = Color.lerp(color, Colors.black, 0.14)!;
  final squash = 1 + pose.breath * 0.03;
  final restBodyH = total * 0.95;
  final bodyH = restBodyH * squash;
  final width = restBodyH * kind.aspect / math.sqrt(squash);
  final lift = pose.bob * total;
  final ground = feet.dy - lift;
  final body = Rect.fromLTWH(
    feet.dx - width / 2,
    ground - total * 0.015 - bodyH,
    width,
    bodyH,
  );
  final bodyPath = beanBodyPath(kind, body);
  final limbW = math.max(total * 0.032, 1.6);

  // Shadow stays on the ground while the bean hops.
  canvas.drawOval(
    Rect.fromCenter(
      center: feet.translate(0, total * 0.012),
      width: width * (1.05 - pose.bob * 0.6),
      height: total * 0.06,
    ),
    fill(Color.lerp(color, Colors.black, 0.55)!.withValues(alpha: 0.2)),
  );

  canvas.save();
  canvas.translate(feet.dx, ground);
  canvas.rotate(pose.step * 0.08);
  canvas.translate(-feet.dx, -ground);

  // Legs come out of the lower sides of the pin, feet turned out.
  for (final side in const [-1.0, 1.0]) {
    final lifted = pose.step * side > 0 ? pose.step.abs() * total * 0.05 : 0.0;
    final hip = Offset(feet.dx + side * width * 0.16, body.top + bodyH * 0.84);
    final ankle = Offset(
      feet.dx + side * width * 0.18,
      ground - total * 0.025 - lifted,
    );
    canvas.drawLine(
      hip,
      ankle,
      fill(limb)
        ..strokeWidth = limbW
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: ankle.translate(side * width * 0.07, total * 0.006),
        width: width * 0.24,
        height: total * 0.045,
      ),
      fill(limb),
    );
  }

  final dir = pose.stickToRight ? 1.0 : -1.0;
  final shoulderY = body.top + bodyH * 0.54;
  final armLen = total * 0.2;
  Path armPath(Offset shoulder, Offset hand, double side) {
    // A soft bend at the elbow, outward.
    final mid = Offset.lerp(shoulder, hand, 0.5)!;
    return Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(
        mid.dx + side * armLen * 0.12,
        mid.dy - armLen * 0.08,
        hand.dx,
        hand.dy,
      );
  }

  Paint armPaint(Color c, double w) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  // The arm on the fire side: resting, or holding the stick.
  final holdShoulder = Offset(feet.dx + dir * width * 0.42, shoulderY);
  final holdHand = pose.ready
      ? holdShoulder.translate(dir * armLen * 0.85, -armLen * 0.05)
      : holdShoulder.translate(dir * armLen * 0.62, armLen * 0.78);
  final holdArm = armPath(holdShoulder, holdHand, dir);

  // The other arm hangs down-out at rest and swings up-out to wave.
  final freeShoulder = Offset(feet.dx - dir * width * 0.42, shoulderY);
  final theta = 0.9 + (-1.05 - 0.9) * pose.wave.clamp(0.0, 1.0);
  final freeHand = freeShoulder.translate(
    -dir * armLen * math.cos(theta),
    armLen * math.sin(theta),
  );
  final freeArm = armPath(freeShoulder, freeHand, -dir);
  final waving = pose.wave > 0.15;

  void drawArm(Path arm, Offset shoulder, Offset hand) {
    canvas.drawPath(arm, armPaint(limb, limbW));
    paintSleeve(
      canvas,
      look.outfit,
      shoulder,
      hand,
      width: limbW,
      alpha: alpha,
    );
  }

  if (pose.ready) {
    final tip = holdHand.translate(dir * total * 0.42, -total * 0.2);
    canvas.drawLine(
      holdHand,
      tip,
      fill(FlatPalette.logDark)
        ..strokeWidth = total * 0.03
        ..strokeCap = StrokeCap.round,
    );
    final puff = Color.lerp(
      FlatPalette.paper,
      const Color(0xFFC98B4F),
      pose.toast.clamp(0.0, 1.0),
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tip, width: total * 0.12, height: total * 0.1),
        Radius.circular(total * 0.035),
      ),
      fill(puff),
    );
  }
  drawArm(holdArm, holdShoulder, holdHand);
  if (!waving) drawArm(freeArm, freeShoulder, freeHand);

  // The body: a soft shade from top to bottom, then a light streak.
  canvas.drawPath(
    bodyPath,
    fill(color)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.black, 0.05)!.withValues(alpha: alpha),
          Color.lerp(color, Colors.white, 0.07)!.withValues(alpha: alpha),
        ],
      ).createShader(body),
  );
  canvas.save();
  canvas.clipPath(bodyPath);
  final r = width / 2;
  canvas.drawArc(
    Rect.fromCircle(
      center: Offset(body.center.dx, body.top + r * 1.02),
      radius: r * 0.8,
    ),
    math.pi * 1.06,
    math.pi * 0.36,
    false,
    fill(Colors.white.withValues(alpha: 0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.26
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();

  // The face: solid black upright eyes with a white shine, a white smile.
  // Sized by the width, so the tall green one does not get long eyes.
  final eyeY = body.top + bodyH * kind.eyeAt;
  final eyeGap = width * 0.106;
  final eyeW = width * 0.095;
  final eyeH = eyeW * 1.9;
  final mouthTop = eyeY + width * 0.15;

  paintOutfit(
    canvas,
    look.outfit,
    bodyPath,
    body,
    bodyColor: color,
    neckY: mouthTop + width * 0.17,
    facingRight: pose.stickToRight,
    alpha: alpha,
  );

  if (waving) drawArm(freeArm, freeShoulder, freeHand);

  final gaze = pose.lookX.clamp(-1.0, 1.0) * width * 0.03;
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(body.center.dx + side * eyeGap + gaze, eyeY);
    if (pose.blink || pose.happy) {
      final path = Path()
        ..moveTo(eye.dx - eyeW * 0.7, eyeY)
        ..quadraticBezierTo(
          eye.dx,
          eyeY + (pose.happy ? -eyeH * 0.4 : eyeH * 0.1),
          eye.dx + eyeW * 0.7,
          eyeY,
        );
      canvas.drawPath(
        path,
        fill(FlatPalette.ink)
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeW * 0.45
          ..strokeCap = StrokeCap.round,
      );
      continue;
    }
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: eyeW, height: eyeH),
      fill(Colors.black),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: eye.translate(eyeW * 0.12, -eyeH * 0.2),
        width: eyeW * 0.36,
        height: eyeW * 0.48,
      ),
      fill(FlatPalette.white),
    );
  }
  final cx = body.center.dx + gaze;
  if (pose.mouthOpen) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, mouthTop + width * 0.06),
        width: width * 0.14,
        height: width * 0.13,
      ),
      fill(FlatPalette.white),
    );
  } else {
    // A white half moon: a gently curved top, a deep round bottom, with
    // rounded corners.
    final half = width * (pose.happy ? 0.12 : 0.109);
    final depth = width * (pose.happy ? 0.13 : 0.115);
    final round = depth * 0.3;
    final top = mouthTop + round * 0.4;
    final smile = Path()
      ..moveTo(cx - half, top)
      ..quadraticBezierTo(cx, top + depth * 0.12, cx + half, top)
      ..cubicTo(
        cx + half * 1.02,
        top + depth * 1.3,
        cx - half * 1.02,
        top + depth * 1.3,
        cx - half,
        top,
      )
      ..close();
    canvas.drawPath(smile, fill(FlatPalette.white));
    canvas.drawPath(
      smile,
      fill(FlatPalette.white)
        ..style = PaintingStyle.stroke
        ..strokeWidth = round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  final hat = look.accessory ?? pose.accessory;
  if (hat != null) {
    // The hat keeps its size while the body breathes: sized by the body
    // at rest and only riding up and down with its top, or it pulses.
    final restWidth = restBodyH * kind.aspect;
    paintHat(
      canvas,
      hat,
      Rect.fromLTWH(
        body.center.dx - restWidth / 2,
        body.top,
        restWidth,
        restBodyH,
      ),
      bodyColor: color,
      alpha: alpha,
      facingRight: pose.stickToRight,
      sway: pose.breath * 0.5,
      eyeY: eyeY,
    );
  }

  if (pose.organizer) {
    // The leader carries a pennant that flutters.
    final pole = Offset(body.right - width * 0.04, body.top + bodyH * 0.18);
    final top = pole.translate(0, -total * 0.45);
    canvas.drawLine(
      pole,
      top,
      fill(FlatPalette.ink)
        ..strokeWidth = total * 0.024
        ..strokeCap = StrokeCap.round,
    );
    final wobble = math.sin(pose.flutter * math.pi * 2) * total * 0.03;
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(
        top.dx + total * 0.13,
        top.dy + wobble,
        top.dx + total * 0.25,
        top.dy + total * 0.065 - wobble * 0.5,
      )
      ..lineTo(top.dx, top.dy + total * 0.15)
      ..close();
    canvas.drawPath(flag, fill(FlatPalette.flameOuter));
  }
  canvas.restore();
}

/// The outline of a [kind] filling [body]: round on top, widest at
/// [BeanKind.widest], narrowing to a point. The red one is an egg with
/// only a small point.
Path beanBodyPath(BeanKind kind, Rect body) {
  final h = body.height;
  final cx = body.center.dx;
  final r = body.width / 2;
  final top = body.top;
  final bottom = body.bottom;
  final widest = top + h * kind.widest;
  final (bulge, tipIn, tipRise) = switch (kind) {
    BeanKind.round => (0.5, 0.42, 0.2),
    BeanKind.tall => (0.18, 0.22, 0.36),
    _ => (0.34, 0.34, 0.26),
  };
  final lower = bottom - widest;
  final tipHalf = r * 0.05;
  return Path()
    ..moveTo(cx, top)
    ..cubicTo(
      cx + r * 0.56,
      top,
      cx + r,
      widest - (widest - top) * 0.46,
      cx + r,
      widest,
    )
    ..cubicTo(
      cx + r,
      widest + lower * bulge,
      cx + r * tipIn,
      bottom - lower * tipRise,
      cx + tipHalf,
      bottom - h * 0.008,
    )
    ..quadraticBezierTo(
      cx,
      bottom + h * 0.004,
      cx - tipHalf,
      bottom - h * 0.008,
    )
    ..cubicTo(
      cx - r * tipIn,
      bottom - lower * tipRise,
      cx - r,
      widest + lower * bulge,
      cx - r,
      widest,
    )
    ..cubicTo(
      cx - r,
      widest - (widest - top) * 0.46,
      cx - r * 0.56,
      top,
      cx,
      top,
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
