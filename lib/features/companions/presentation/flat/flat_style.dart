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
  pin('pin', 'Синий', Color(0xFF2474CF), 1, 0.74, 0.03, 0.317, 0.54, 0.168),
  tall(
    'tall',
    'Зелёный',
    Color(0xFF1EC3A6),
    1.36,
    0.54,
    0.04,
    0.236,
    0.51,
    0.11,
  ),
  small(
    'small',
    'Жёлтый',
    Color(0xFFF7C928),
    0.58,
    0.73,
    0.06,
    0.31,
    0.53,
    0.15,
  ),
  round(
    'round',
    'Красный',
    Color(0xFFDD2D2F),
    0.99,
    0.75,
    0.08,
    0.32,
    0.57,
    0.18,
  );

  const BeanKind(
    this.slug,
    this.title,
    this.color,
    this.size,
    this.aspect,
    this.legs,
    this.eyeAt,
    this.shoulderAt,
    this.hip,
  );

  /// The server's name for it.
  final String slug;
  final String title;
  final Color color;

  /// Body height against the blue one: the green is taller, the yellow a
  /// kid (measured on the sketch).
  final double size;

  /// Body width to body height.
  final double aspect;

  /// How much leg shows under the point, in body heights: the yellow and
  /// the red stand a little higher.
  final double legs;

  /// Where the eyes and the arms sit, from the top, in body heights.
  final double eyeAt;
  final double shoulderAt;

  /// How far from the middle the legs come out, in body widths.
  final double hip;

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

/// The blue character's body height when it stands [height] tall.
double _blueBody(double height) => height / (1 + BeanKind.pin.legs);

/// How tall a bean of [kind] stands, feet to top, when the blue one is
/// [height].
double beanHeight(BeanKind kind, double height) =>
    _blueBody(height) * kind.size * (1 + kind.legs);

/// The outline of a character inside [rect] and its width at any height.
///
/// Three of them are a map pin as on the sketch: a circle on top and two
/// straight sides down to the point, tangent to it. The red one is an egg:
/// the same circle on top, then a round bottom with only a small point.
class BeanBody {
  BeanBody(this.kind, this.rect) {
    final d = rect.bottom - cy;
    if (kind == BeanKind.round) {
      _p1 = Offset(r * 1.02, cy + d * 0.72);
      _p2 = Offset(r * 0.38, rect.bottom - d * 0.1);
      path = Path()
        ..moveTo(cx + r, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          0,
          -math.pi,
          false,
        )
        ..cubicTo(cx - _p1.dx, _p1.dy, cx - _p2.dx, _p2.dy, cx, rect.bottom)
        ..cubicTo(cx + _p2.dx, _p2.dy, cx + _p1.dx, _p1.dy, cx + r, cy)
        ..close();
      return;
    }
    final phi = math.acos((r / d).clamp(0.0, 1.0));
    _tangent = Offset(r * math.sin(phi), cy + r * math.cos(phi));
    final tip = rect.bottom;
    final round = r * 0.05;
    // The sides bow out a touch, as drawn by hand.
    Offset side(double sign) => Offset(
      cx + sign * (_tangent.dx * 0.5 + r * 0.035),
      (_tangent.dy + tip) / 2,
    );
    path = Path()
      ..moveTo(cx + _tangent.dx, _tangent.dy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi / 2 - phi,
        -(2 * math.pi - 2 * phi),
        false,
      )
      ..quadraticBezierTo(
        side(-1).dx,
        side(-1).dy,
        cx - round,
        tip - round * 1.2,
      )
      ..quadraticBezierTo(cx, tip + round * 0.2, cx + round, tip - round * 1.2)
      ..quadraticBezierTo(side(1).dx, side(1).dy, cx + _tangent.dx, _tangent.dy)
      ..close();
  }

  final BeanKind kind;
  final Rect rect;
  late final Path path;
  Offset _tangent = Offset.zero;
  Offset _p1 = Offset.zero;
  Offset _p2 = Offset.zero;

  double get r => rect.width / 2;
  double get cx => rect.center.dx;
  double get cy => rect.top + r;

  /// Half the body's width at [y].
  double halfWidthAt(double y) {
    if (y <= rect.top || y >= rect.bottom) return 0;
    if (y <= cy) return math.sqrt(math.max(0, r * r - (y - cy) * (y - cy)));
    if (kind != BeanKind.round) {
      if (y <= _tangent.dy) {
        return math.sqrt(math.max(0, r * r - (y - cy) * (y - cy)));
      }
      return _tangent.dx * (rect.bottom - y) / (rect.bottom - _tangent.dy);
    }
    // The egg's bottom: find the point of the curve at this height.
    var lo = 0.0;
    var hi = 1.0;
    double at(double t, double a, double b, double c, double e) {
      final u = 1 - t;
      return u * u * u * a +
          3 * u * u * t * b +
          3 * u * t * t * c +
          t * t * t * e;
    }

    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (at(mid, cy, _p1.dy, _p2.dy, rect.bottom) < y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return at(lo, r, _p1.dx, _p2.dx, 0);
  }
}

/// A bean whose blue build stands [height] tall, with its feet at [feet].
/// The others are taller or shorter as on the sketch.
///
/// The owner's sketch (FRONTEND-79): a pin with a soft shade and a light
/// streak on the top left; short arms that go down and turn out at the
/// end; straight legs with long feet turned out; upright black eyes with a
/// shine and a white smile. Clothes are bulky, wider than the body, with
/// fat sleeves and little hands out of the cuffs.
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
  final limb = Color.lerp(color, Colors.black, 0.1)!;
  final squash = 1 + pose.breath * 0.03;
  final restH = _blueBody(height) * kind.size;
  final bodyH = restH * squash;
  final width = restH * kind.aspect / math.sqrt(squash);
  final lift = pose.bob * restH;
  final ground = feet.dy - lift;
  final bodyBottom = ground - restH * kind.legs;
  final body = BeanBody(
    kind,
    Rect.fromLTWH(feet.dx - width / 2, bodyBottom - bodyH, width, bodyH),
  );
  final rect = body.rect;
  final cx = body.cx;
  final limbW = width * 0.045;
  final dir = pose.stickToRight ? 1.0 : -1.0;

  // A soft shadow in the body's own colour stays on the ground.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(feet.dx, feet.dy),
      width: width * (0.8 - pose.bob * 0.5),
      height: width * 0.11,
    ),
    fill(color.withValues(alpha: 0.16)),
  );

  canvas.save();
  canvas.translate(feet.dx, ground);
  canvas.rotate(pose.step * 0.07);
  canvas.translate(-feet.dx, -ground);

  Paint stroke(Color c, double w, [StrokeCap cap = StrokeCap.round]) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap;

  // Legs: straight down from under the body, long feet turned out.
  for (final side in const [-1.0, 1.0]) {
    final lifted = pose.step * side > 0 ? pose.step.abs() * width * 0.08 : 0.0;
    final hip = Offset(
      cx + side * width * kind.hip,
      rect.bottom - restH * 0.12,
    );
    final ankle = Offset(
      cx + side * width * (kind.hip + 0.022),
      ground - limbW * 0.55 - lifted,
    );
    canvas.drawLine(hip, ankle, stroke(limb, limbW));
    canvas.drawLine(
      ankle,
      ankle.translate(side * width * 0.11, limbW * 0.1),
      stroke(limb, limbW * 1.12),
    );
  }

  final outfit = look.outfit;
  final eyeY = rect.top + bodyH * kind.eyeAt;
  final neckY = eyeY + width * 0.29;
  final torso = outfitTorso(outfit, body, neckY);

  // An arm: where it starts, where it points at rest, and how far it is
  // turned up (waving, or reaching to the fire).
  Offset rotate(Offset v, double a) => Offset(
    v.dx * math.cos(a) - v.dy * math.sin(a),
    v.dx * math.sin(a) + v.dy * math.cos(a),
  );
  final sleeved = torso != null && outfitHasSleeves(outfit);
  final waveTurn = 2.1 * pose.wave.clamp(0.0, 1.0);
  final arms = <(double, Offset, Offset)>[];
  for (final side in const [-1.0, 1.0]) {
    final holds = side == dir;
    final turn = holds ? (pose.ready ? 1.05 : 0.0) : waveTurn;
    final shoulderY = rect.top + bodyH * kind.shoulderAt;
    final shoulder = sleeved
        ? Offset(cx + side * torso.topHalf * 0.86, neckY + width * 0.08)
        : Offset(cx + side * body.halfWidthAt(shoulderY) * 0.93, shoulderY);
    final rest = sleeved
        ? Offset(side * width * 0.12, width * 0.24)
        : Offset(side * width * 0.15, width * 0.17);
    arms.add((side, shoulder, rotate(rest, -side * turn)));
    if (!sleeved) {
      // Bare arms start steep and turn out at the end.
      final ctrl =
          shoulder +
          rotate(Offset(rest.dx * 0.42, rest.dy * 0.68), -side * turn);
      final hand = shoulder + rotate(rest, -side * turn);
      canvas.drawPath(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, hand.dx, hand.dy),
        stroke(limb, limbW),
      );
    }
  }

  if (pose.ready) {
    final arm = arms.firstWhere((a) => a.$1 == dir);
    final hand = arm.$2 + arm.$3;
    final tip = hand.translate(dir * width * 0.5, -width * 0.3);
    canvas.drawLine(hand, tip, stroke(FlatPalette.logDark, width * 0.04));
    final puff = Color.lerp(
      FlatPalette.paper,
      const Color(0xFFC98B4F),
      pose.toast.clamp(0.0, 1.0),
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tip, width: width * 0.16, height: width * 0.14),
        Radius.circular(width * 0.05),
      ),
      fill(puff),
    );
  }

  // The body: a soft shade from top to bottom, a light streak top left.
  canvas.drawPath(
    body.path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.03)!.withValues(alpha: alpha),
          Color.lerp(color, Colors.black, 0.06)!.withValues(alpha: alpha),
        ],
      ).createShader(rect),
  );
  canvas.save();
  canvas.clipPath(body.path);
  canvas.drawArc(
    Rect.fromCircle(center: Offset(cx, body.cy), radius: body.r * 0.86),
    math.pi * 1.08,
    math.pi * 0.3,
    false,
    stroke(Colors.white.withValues(alpha: 0.08), body.r * 0.2),
  );
  canvas.restore();

  if (sleeved) {
    for (final (_, shoulder, v) in arms) {
      paintSleeve(
        canvas,
        outfit,
        shoulder,
        shoulder + v,
        width: width,
        handColor: limb,
        alpha: alpha,
      );
    }
  }
  if (torso != null) {
    paintOutfit(
      canvas,
      outfit,
      torso,
      body,
      bodyColor: color,
      facingRight: pose.stickToRight,
      alpha: alpha,
    );
  }

  // The face. Sized by the width, so the tall green one keeps round eyes.
  final eyeGap = width * 0.106;
  final eyeW = width * 0.095;
  final eyeH = eyeW * 1.95;
  final gaze = pose.lookX.clamp(-1.0, 1.0) * width * 0.03;
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(cx + side * eyeGap + gaze, eyeY);
    if (pose.blink || pose.happy) {
      canvas.drawPath(
        Path()
          ..moveTo(eye.dx - eyeW * 0.7, eyeY)
          ..quadraticBezierTo(
            eye.dx,
            eyeY + (pose.happy ? -eyeH * 0.4 : eyeH * 0.1),
            eye.dx + eyeW * 0.7,
            eyeY,
          ),
        stroke(Colors.black, eyeW * 0.45),
      );
      continue;
    }
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: eyeW, height: eyeH),
      fill(Colors.black),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: eye.translate(eyeW * 0.17, -eyeH * 0.2),
        width: eyeW * 0.26,
        height: eyeH * 0.26,
      ),
      fill(FlatPalette.white),
    );
  }
  final mouthTop = eyeY + width * 0.144;
  final mx = cx + gaze;
  if (pose.mouthOpen) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(mx, mouthTop + width * 0.06),
        width: width * 0.13,
        height: width * 0.12,
      ),
      fill(FlatPalette.white),
    );
  } else {
    // A white half moon: an almost flat top, a deep round bottom.
    final half = width * (pose.happy ? 0.12 : 0.109);
    final depth = width * (pose.happy ? 0.135 : 0.123);
    final smile = Path()
      ..moveTo(mx - half, mouthTop)
      ..quadraticBezierTo(mx, mouthTop + depth * 0.1, mx + half, mouthTop)
      ..cubicTo(
        mx + half * 0.98,
        mouthTop + depth * 1.32,
        mx - half * 0.98,
        mouthTop + depth * 1.32,
        mx - half,
        mouthTop,
      )
      ..close();
    canvas.drawPath(smile, fill(FlatPalette.white));
    canvas.drawPath(
      smile,
      fill(FlatPalette.white)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.02
        ..strokeJoin = StrokeJoin.round,
    );
  }

  final hat = look.accessory ?? pose.accessory;
  if (hat != null) {
    // The hat keeps its size while the body breathes.
    final restWidth = restH * kind.aspect;
    paintHat(
      canvas,
      hat,
      Rect.fromLTWH(cx - restWidth / 2, rect.top, restWidth, restH),
      bodyColor: color,
      alpha: alpha,
      facingRight: pose.stickToRight,
      sway: pose.breath * 0.5,
      eyeY: eyeY,
    );
  }

  if (pose.organizer) {
    // The leader carries a pennant that flutters.
    final pole = Offset(rect.right - width * 0.04, rect.top + bodyH * 0.18);
    final top = pole.translate(0, -width * 0.6);
    canvas.drawLine(pole, top, stroke(FlatPalette.ink, width * 0.035));
    final wobble = math.sin(pose.flutter * math.pi * 2) * width * 0.04;
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + width * 0.18,
          top.dy + wobble,
          top.dx + width * 0.34,
          top.dy + width * 0.09 - wobble * 0.5,
        )
        ..lineTo(top.dx, top.dy + width * 0.2)
        ..close(),
      fill(FlatPalette.flameOuter),
    );
  }
  canvas.restore();
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
