import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_art.dart';
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

/// The four characters the designer drew (FRONTEND-79, 2026-10-15): one
/// map pin in four builds, each with its own colour. A person picks one;
/// all four are free.
enum BeanKind {
  pin('pin', 'Синий', Color(0xFF2474CF)),
  tall('tall', 'Зелёный', Color(0xFF1AB59E)),
  small('small', 'Жёлтый', Color(0xFFFFCE2D)),
  round('round', 'Красный', Color(0xFFD62D30));

  const BeanKind(this.slug, this.title, this.color);

  /// The server's name for it.
  final String slug;
  final String title;
  final Color color;

  /// The designer's drawing of it.
  BeanArt get art => BeanArt.of(beanArtData(slug));

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

/// How tall a bean of [kind] stands, feet to top, when the blue one is
/// [height].
double beanHeight(BeanKind kind, double height) =>
    height * kind.art.data.size.height / beanArtBlueHeight;

/// The body of a character for clothes: its box and its width at any
/// height, in the drawing's units.
class BeanBody {
  const BeanBody(this.art);

  final BeanArt art;

  Rect get rect => art.bodyBounds;
  double get cx => rect.center.dx;
  double halfWidthAt(double y) => art.halfWidthAt(y);
}

/// A bean whose blue build stands [height] tall, with its feet at [feet].
///
/// Drawn from the designer's SVGs (FRONTEND-79) part by part: the arms
/// turn at the shoulder to wave or to hold the stick, a foot lifts to walk,
/// and the eyes and the mouth change for blinking, joy and «о!». Clothes
/// and hats are drawn over it in the same units.
void paintBean(
  Canvas canvas,
  Offset feet,
  double height,
  Color color,
  BeanPose pose,
) {
  final look = pose.look ?? const BeanLook();
  final art = look.kind.art;
  final data = art.data;
  final g = data.ground;
  final b = art.bodyBounds;
  final w = b.width;
  final limb = data.limbColor;
  Paint fill(Color c) => Paint()..color = c;
  Paint stroke(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  canvas.save();
  canvas.translate(feet.dx, feet.dy);
  canvas.scale(height / beanArtBlueHeight);
  canvas.translate(-g.dx, -g.dy);
  if (pose.dim) {
    // Not started yet: the whole figure faded, like a ghost of itself.
    canvas.saveLayer(null, Paint()..color = const Color(0x61000000));
  }

  // The shadow stays on the ground and shrinks while the bean hops.
  canvas.save();
  canvas.translate(g.dx, g.dy);
  canvas.scale(1 - pose.bob * 0.5, 1);
  canvas.translate(-g.dx, -g.dy);
  canvas.drawPath(art.shadow, fill(data.shadowColor.withValues(alpha: 0.15)));
  canvas.restore();

  canvas.translate(0, -pose.bob * data.size.height);
  canvas.translate(g.dx, g.dy);
  canvas.rotate(pose.step * 0.07);
  canvas.translate(-g.dx, -g.dy);

  for (final (leg, side) in [(art.legLeft, -1.0), (art.legRight, 1.0)]) {
    final lifted = pose.step * side > 0 ? pose.step.abs() * w * 0.08 : 0.0;
    canvas.drawPath(leg.shift(Offset(0, -lifted)), fill(limb));
  }

  // Breathing squashes and stretches everything above the legs.
  final squash = 1 + pose.breath * 0.03;
  canvas.translate(g.dx, g.dy);
  canvas.scale(1 / math.sqrt(squash), squash);
  canvas.translate(-g.dx, -g.dy);

  final outfit = look.outfit;
  final eyes = art.eyeLeft.getBounds().expandToInclude(
    art.eyeRight.getBounds(),
  );
  final mouth = art.mouth.getBounds();
  final body = BeanBody(art);
  final torso = outfitTorso(outfit, body, mouth.bottom + w * 0.025);
  final sleeved = torso != null && outfitHasSleeves(outfit);
  final dir = pose.stickToRight ? 1.0 : -1.0;
  final waveTurn = 2.1 * pose.wave.clamp(0.0, 1.0);
  Offset turned(Offset p, Offset pivot, double angle) {
    final v = p - pivot;
    return pivot +
        Offset(
          v.dx * math.cos(angle) - v.dy * math.sin(angle),
          v.dx * math.sin(angle) + v.dy * math.cos(angle),
        );
  }

  // Each arm: which side, its path, where it turns, its hand, how far up.
  final arms = [
    (-1.0, art.armLeft, art.shoulderLeft, art.handLeft),
    (1.0, art.armRight, art.shoulderRight, art.handRight),
  ];
  final hands = <double, Offset>{};
  final sleeves = <(Offset, Offset)>[];
  for (final (side, path, shoulder, hand) in arms) {
    final holds = side == dir;
    final turn = holds ? (pose.ready ? 1.05 : 0.0) : waveTurn;
    // Raising the left arm out turns it clockwise, the right one back.
    final angle = -side * turn;
    if (sleeved) {
      final from = Offset(
        body.cx + side * torso.topHalf * 0.86,
        torso.top + w * 0.08,
      );
      final to = turned(from + Offset(side * w * 0.12, w * 0.24), from, angle);
      sleeves.add((from, to));
      hands[side] = to;
      continue;
    }
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    canvas.translate(-shoulder.dx, -shoulder.dy);
    canvas.drawPath(path, fill(limb));
    canvas.restore();
    hands[side] = turned(hand, shoulder, angle);
  }

  if (pose.ready) {
    final hand = hands[dir]!;
    final tip = hand.translate(dir * w * 0.5, -w * 0.3);
    canvas.drawLine(hand, tip, stroke(FlatPalette.logDark, w * 0.04));
    final puff = Color.lerp(
      FlatPalette.paper,
      const Color(0xFFC98B4F),
      pose.toast.clamp(0.0, 1.0),
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tip, width: w * 0.16, height: w * 0.14),
        Radius.circular(w * 0.05),
      ),
      fill(puff),
    );
  }

  // The body whole, notch and all, then the highlight over it as a soft
  // blurred patch: the designer's picture has it blurred, the SVG export
  // lost that and left a hard edge.
  canvas.drawPath(
    art.solidBody,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [data.bodyTop, data.bodyBottom],
      ).createShader(b),
  );
  canvas.save();
  canvas.clipPath(art.solidBody);
  canvas.drawPath(
    art.highlight,
    fill(data.highlightColor)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.022),
  );
  canvas.restore();

  for (final (from, to) in sleeves) {
    paintSleeve(canvas, outfit, from, to, width: w, handColor: limb, alpha: 1);
  }
  if (torso != null) {
    paintOutfit(
      canvas,
      outfit,
      torso,
      body,
      bodyColor: data.bodyTop,
      facingRight: pose.stickToRight,
      alpha: 1,
    );
  }

  // The face: the designer's eyes and smile, swapped for a blink, joy or
  // an open «о!».
  final gaze = Offset(pose.lookX.clamp(-1.0, 1.0) * w * 0.03, 0);
  for (final (eye, shine) in [
    (art.eyeLeft, art.shineLeft),
    (art.eyeRight, art.shineRight),
  ]) {
    final box = eye.getBounds().shift(gaze);
    if (pose.blink || pose.happy) {
      final y = box.center.dy;
      canvas.drawPath(
        Path()
          ..moveTo(box.left - box.width * 0.15, y)
          ..quadraticBezierTo(
            box.center.dx,
            y + (pose.happy ? -box.height * 0.42 : box.height * 0.08),
            box.right + box.width * 0.15,
            y,
          ),
        stroke(Colors.black, box.width * 0.42),
      );
      continue;
    }
    canvas.drawPath(eye.shift(gaze), fill(Colors.black));
    canvas.drawPath(shine.shift(gaze), fill(Colors.white));
  }
  if (pose.mouthOpen) {
    canvas.drawOval(
      Rect.fromCenter(
        center: mouth.center + gaze,
        width: mouth.width * 0.55,
        height: mouth.height * 0.95,
      ),
      fill(Colors.white),
    );
  } else {
    canvas.save();
    final top = Offset(mouth.center.dx, mouth.top) + gaze;
    canvas.translate(top.dx, top.dy);
    if (pose.happy) canvas.scale(1.12);
    canvas.translate(-top.dx + gaze.dx, -top.dy);
    canvas.drawPath(art.mouth, fill(Colors.white));
    canvas.restore();
  }

  final hat = look.accessory ?? pose.accessory;
  if (hat != null) {
    paintHat(
      canvas,
      hat,
      b,
      bodyColor: data.bodyTop,
      alpha: 1,
      facingRight: pose.stickToRight,
      sway: pose.breath * 0.5,
      eyeY: eyes.center.dy,
    );
  }

  if (pose.organizer) {
    // The leader carries a pennant that flutters.
    final pole = Offset(b.right - w * 0.04, b.top + b.height * 0.18);
    final top = pole.translate(0, -w * 0.6);
    canvas.drawLine(pole, top, stroke(FlatPalette.ink, w * 0.035));
    final wobble = math.sin(pose.flutter * math.pi * 2) * w * 0.04;
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + w * 0.18,
          top.dy + wobble,
          top.dx + w * 0.34,
          top.dy + w * 0.09 - wobble * 0.5,
        )
        ..lineTo(top.dx, top.dy + w * 0.2)
        ..close(),
      fill(FlatPalette.flameOuter),
    );
  }
  if (pose.dim) canvas.restore();
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
