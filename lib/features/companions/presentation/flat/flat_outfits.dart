import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart'
    show BeanBody;

/// What a companion's character wears on the body (FRONTEND-79, the
/// owner's sketch of 2026-10-15). Clothes are bulky as on the sketch: a
/// piece of its own, wider than the body, from the chin down to above the
/// legs, with fat sleeves and little hands out of the cuffs.
enum BeanOutfit {
  none('none'),
  varsity('varsity'),
  hoodie('hoodie'),
  sweater('sweater'),
  vest('vest');

  const BeanOutfit(this.slug);

  /// The server's name for it.
  final String slug;

  static BeanOutfit? fromSlug(String? slug) {
    for (final outfit in values) {
      if (outfit.slug == slug) return outfit;
    }
    return null;
  }
}

const _navy = Color(0xFF1E2F5E);
const _navyDark = Color(0xFF17254C);
const _cream = Color(0xFFF2E7CF);
const _lavender = Color(0xFFAA97DD);
const _lavenderDark = Color(0xFF9784D0);
const _lavenderLight = Color(0xFFBCADE8);
const _vest = Color(0xFFF1E8D4);
const _vestDark = Color(0xFFE0D3B8);
const _bag = Color(0xFF1F7F5F);
const _bagDark = Color(0xFF17664C);

/// The torso a piece of clothing takes: its outline and where it sits.
class OutfitTorso {
  const OutfitTorso({
    required this.path,
    required this.top,
    required this.hem,
    required this.topHalf,
    required this.bottomHalf,
  });

  final Path path;
  final double top;
  final double hem;
  final double topHalf;
  final double bottomHalf;
}

/// Whether [outfit] has sleeves; a vest leaves the arms bare.
bool outfitHasSleeves(BeanOutfit outfit) =>
    outfit == BeanOutfit.varsity ||
    outfit == BeanOutfit.hoodie ||
    outfit == BeanOutfit.sweater;

/// The torso of [outfit] on [body], from [neckY] (just under the smile)
/// down; none without clothes.
OutfitTorso? outfitTorso(BeanOutfit outfit, BeanBody body, double neckY) {
  if (outfit == BeanOutfit.none) return null;
  final rect = body.rect;
  final w = rect.width;
  final h = rect.height;
  final vest = outfit == BeanOutfit.vest;
  final hem = math.min(
    neckY + h * (vest ? 0.32 : 0.36),
    rect.top + h * (vest ? 0.84 : 0.86),
  );
  final topHalf =
      body.halfWidthAt(neckY + w * 0.05) * (vest ? 1.03 : 1.08) + w * 0.02;
  final bottomHalf = math.max(
    topHalf * (vest ? 0.78 : 0.86),
    body.halfWidthAt(hem) + w * 0.06,
  );
  final dip = switch (outfit) {
    BeanOutfit.sweater => w * 0.05,
    BeanOutfit.varsity => w * 0.03,
    _ => w * 0.01,
  };
  return OutfitTorso(
    path: _trapezoid(
      body.cx,
      neckY,
      hem,
      topHalf,
      bottomHalf,
      w * (vest ? 0.08 : 0.13),
      w * 0.05,
      dip,
    ),
    top: neckY,
    hem: hem,
    topHalf: topHalf,
    bottomHalf: bottomHalf,
  );
}

Path _trapezoid(
  double cx,
  double top,
  double hem,
  double topHalf,
  double bottomHalf,
  double rTop,
  double rBottom,
  double dip,
) {
  final tl = Offset(cx - topHalf, top);
  final tr = Offset(cx + topHalf, top);
  final br = Offset(cx + bottomHalf, hem);
  final bl = Offset(cx - bottomHalf, hem);
  Offset toward(Offset a, Offset b, double d) {
    final v = b - a;
    return a + v / v.distance * d;
  }

  final tlR = toward(tl, tr, rTop);
  final trL = toward(tr, tl, rTop);
  final trD = toward(tr, br, rTop);
  final brU = toward(br, tr, rBottom);
  final brL = toward(br, bl, rBottom);
  final blR = toward(bl, br, rBottom);
  final blU = toward(bl, tl, rBottom);
  final tlD = toward(tl, bl, rTop);
  return Path()
    ..moveTo(tlR.dx, tlR.dy)
    ..quadraticBezierTo(cx, top + dip * 2, trL.dx, trL.dy)
    ..quadraticBezierTo(tr.dx, tr.dy, trD.dx, trD.dy)
    ..lineTo(brU.dx, brU.dy)
    ..quadraticBezierTo(br.dx, br.dy, brL.dx, brL.dy)
    ..lineTo(blR.dx, blR.dy)
    ..quadraticBezierTo(bl.dx, bl.dy, blU.dx, blU.dy)
    ..lineTo(tlD.dx, tlD.dy)
    ..quadraticBezierTo(tl.dx, tl.dy, tlR.dx, tlR.dy)
    ..close();
}

/// A fat sleeve from [shoulder] to [hand] with its cuff, and the little
/// hand out of it. [width] is the body's width.
void paintSleeve(
  Canvas canvas,
  BeanOutfit outfit,
  Offset shoulder,
  Offset hand, {
  required double width,
  required Color handColor,
  required double alpha,
}) {
  final (cloth, cuff) = switch (outfit) {
    BeanOutfit.varsity => (_cream, _navy),
    BeanOutfit.hoodie => (_lavender, _lavenderDark),
    _ => (_navy, _navyDark),
  };
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  Paint stroke(Color c, double w, StrokeCap cap) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap;
  final sleeveW = width * 0.18;
  final v = hand - shoulder;
  final unit = v / v.distance;
  final across = Offset(-unit.dy, unit.dx);

  // The hand first: the cuff covers its root.
  canvas.drawCircle(hand + unit * width * 0.05, width * 0.065, fill(handColor));
  canvas.drawCircle(shoulder, sleeveW / 2, fill(cloth));
  canvas.drawLine(shoulder, hand, stroke(cloth, sleeveW, StrokeCap.butt));
  final cuffFrom = shoulder + v * 0.8;
  canvas.drawLine(cuffFrom, hand, stroke(cuff, sleeveW * 1.04, StrokeCap.butt));
  if (outfit == BeanOutfit.varsity) {
    // Two white stripes round the cuff.
    for (final t in const [0.84, 0.93]) {
      final at = shoulder + v * t;
      canvas.drawLine(
        at - across * sleeveW * 0.5,
        at + across * sleeveW * 0.5,
        stroke(_cream, width * 0.014, StrokeCap.butt),
      );
    }
  } else {
    // Ribs along the cuff.
    final rib = Color.lerp(cuff, Colors.black, 0.12)!;
    for (final k in const [-0.25, 0.0, 0.25]) {
      final off = across * sleeveW * k;
      canvas.drawLine(
        cuffFrom + off,
        hand + off,
        stroke(rib, width * 0.01, StrokeCap.butt),
      );
    }
  }
}

/// [outfit] on [body] over its [torso].
void paintOutfit(
  Canvas canvas,
  BeanOutfit outfit,
  OutfitTorso torso,
  BeanBody body, {
  required Color bodyColor,
  required bool facingRight,
  required double alpha,
}) {
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  Paint stroke(Color c, double w) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
  final w = body.rect.width;
  final cx = body.cx;
  final top = torso.top;
  final hem = torso.hem;
  final tall = hem - top;
  final dir = facingRight ? 1.0 : -1.0;
  Path band(double from, double to) => Path.combine(
    PathOperation.intersect,
    torso.path,
    Path()..addRect(Rect.fromLTRB(cx - w * 2, from, cx + w * 2, to)),
  );
  // The top edge of the torso, for collars.
  final collar = Path()
    ..moveTo(cx - torso.topHalf * 0.8, top + w * 0.02)
    ..quadraticBezierTo(
      cx,
      top + (outfit == BeanOutfit.sweater ? w * 0.12 : w * 0.07),
      cx + torso.topHalf * 0.8,
      top + w * 0.02,
    );

  switch (outfit) {
    case BeanOutfit.none:
      return;

    case BeanOutfit.varsity:
      // Two navy panels, open at the front where the body shows.
      final gap = Path()
        ..moveTo(cx - w * 0.09, top - w)
        ..lineTo(cx + w * 0.09, top - w)
        ..lineTo(cx + w * 0.06, hem + w)
        ..lineTo(cx - w * 0.06, hem + w)
        ..close();
      final panels = Path.combine(PathOperation.difference, torso.path, gap);
      canvas.drawPath(panels, fill(_navy));
      canvas.save();
      canvas.clipPath(panels);
      // White piping down the front edges.
      for (final side in const [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(cx + side * w * 0.11, top),
          Offset(cx + side * w * 0.08, hem),
          stroke(_cream, w * 0.02),
        );
      }
      // Ribbed collar and hem, each with white stripes.
      canvas.drawPath(collar, stroke(_navyDark, w * 0.08));
      canvas.drawPath(
        collar.shift(Offset(0, w * 0.02)),
        stroke(_cream, w * 0.012),
      );
      canvas.drawPath(band(hem - w * 0.08, hem), fill(_navyDark));
      for (final y in [hem - w * 0.058, hem - w * 0.028]) {
        canvas.drawLine(
          Offset(cx - w, y),
          Offset(cx + w, y),
          stroke(_cream, w * 0.012),
        );
      }
      // Pocket welts, slanting.
      for (final side in const [-1.0, 1.0]) {
        final at = Offset(
          cx + side * torso.bottomHalf * 0.55,
          top + tall * 0.62,
        );
        canvas.drawLine(
          at.translate(-side * w * 0.03, -w * 0.06),
          at.translate(side * w * 0.03, w * 0.06),
          stroke(_cream, w * 0.02),
        );
      }
      canvas.restore();

    case BeanOutfit.hoodie:
      // A V at the neck where the hood crosses; the chin sits in it.
      final vee = Path()
        ..moveTo(cx - w * 0.15, top - w)
        ..lineTo(cx + w * 0.15, top - w)
        ..lineTo(cx + w * 0.15, top)
        ..lineTo(cx, top + w * 0.17)
        ..lineTo(cx - w * 0.15, top)
        ..close();
      final cloth = Path.combine(PathOperation.difference, torso.path, vee);
      canvas.drawPath(cloth, fill(_lavender));
      canvas.save();
      canvas.clipPath(cloth);
      // The hood lies round the neck as a soft roll.
      canvas.drawPath(
        Path()
          ..moveTo(cx - torso.topHalf, top + w * 0.02)
          ..lineTo(cx - w * 0.15, top + w * 0.01)
          ..lineTo(cx, top + w * 0.17)
          ..lineTo(cx + w * 0.15, top + w * 0.01)
          ..lineTo(cx + torso.topHalf, top + w * 0.02),
        stroke(_lavenderLight, w * 0.09)..strokeJoin = StrokeJoin.round,
      );
      // The kangaroo pocket.
      canvas.drawPath(
        _trapezoid(
          cx,
          top + tall * 0.58,
          hem - w * 0.05,
          torso.bottomHalf * 0.52,
          torso.bottomHalf * 0.66,
          w * 0.03,
          w * 0.03,
          0,
        ),
        fill(_lavenderDark),
      );
      canvas.restore();
      // Drawstrings with round tips.
      for (final side in const [-1.0, 1.0]) {
        final from = Offset(cx + side * w * 0.06, top + w * 0.13);
        final to = from.translate(side * w * 0.005, w * 0.15);
        canvas.drawLine(from, to, stroke(_cream, w * 0.022));
        canvas.drawCircle(to, w * 0.026, fill(_cream));
      }

    case BeanOutfit.sweater:
      canvas.drawPath(torso.path, fill(_navy));
      canvas.drawPath(band(top + tall * 0.36, top + tall * 0.62), fill(_cream));
      // Ribbed collar roll and hem.
      canvas.save();
      canvas.clipPath(torso.path);
      canvas.drawPath(collar, stroke(_navyDark, w * 0.1));
      canvas.restore();
      final ribbed = band(hem - w * 0.08, hem);
      canvas.drawPath(ribbed, fill(_navyDark));
      canvas.save();
      canvas.clipPath(ribbed);
      for (var x = cx - w; x < cx + w; x += w * 0.055) {
        canvas.drawLine(
          Offset(x, hem - w * 0.08),
          Offset(x, hem),
          stroke(_navy, w * 0.012),
        );
      }
      canvas.restore();

    case BeanOutfit.vest:
      // A light vest open at the front, a pocket on one side.
      final gap = Path()
        ..moveTo(cx - w * 0.1, top - w)
        ..lineTo(cx + w * 0.1, top - w)
        ..lineTo(cx + w * 0.14, hem + w)
        ..lineTo(cx - w * 0.14, hem + w)
        ..close();
      final panels = Path.combine(PathOperation.difference, torso.path, gap);
      canvas.drawPath(panels, fill(_vest));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              cx - dir * torso.bottomHalf * 0.6,
              top + tall * 0.42,
            ),
            width: w * 0.17,
            height: w * 0.15,
          ),
          Radius.circular(w * 0.025),
        ),
        fill(_vestDark),
      );
      // The crossbody bag: a strap from the far shoulder to the near hip.
      final strapFrom = Offset(cx - dir * torso.topHalf * 0.75, top + w * 0.02);
      final bagCenter = Offset(
        cx + dir * torso.bottomHalf * 0.95,
        top + tall * 0.7,
      );
      canvas.drawLine(strapFrom, bagCenter, stroke(_bagDark, w * 0.04));
      final bag = RRect.fromRectAndRadius(
        Rect.fromCenter(center: bagCenter, width: w * 0.38, height: w * 0.28),
        Radius.circular(w * 0.07),
      );
      canvas.drawRRect(bag, fill(_bag));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(bag.left, bag.top, bag.width, bag.height * 0.48),
          topLeft: Radius.circular(w * 0.07),
          topRight: Radius.circular(w * 0.07),
          bottomLeft: Radius.circular(w * 0.03),
          bottomRight: Radius.circular(w * 0.03),
        ),
        fill(_bagDark),
      );
      canvas.drawCircle(
        Offset(bagCenter.dx, bag.top + bag.height * 0.48),
        math.max(w * 0.026, 1),
        fill(_cream),
      );
  }
}
