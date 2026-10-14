import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What a companion's character wears on the body (FRONTEND-79, the
/// owner's sketch of 2026-10-15). Flat like the hats: two or three tones,
/// stripes and pockets drawn as shapes. Each piece sits between the chin
/// and the legs and follows the outline of the body.
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
const _cream = Color(0xFFF2E7CF);
const _lavender = Color(0xFFA996DC);
const _lavenderDark = Color(0xFF9683CF);
const _lavenderLight = Color(0xFFB9A9E6);
const _vest = Color(0xFFF1E8D4);
const _vestDark = Color(0xFFE2D6BC);
const _bag = Color(0xFF1F7F5F);
const _bagDark = Color(0xFF17664C);

Color _shade(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;

/// The sleeve over an arm from [shoulder] to [hand], [width] thick.
void paintSleeve(
  Canvas canvas,
  BeanOutfit outfit,
  Offset shoulder,
  Offset hand, {
  required double width,
  required double alpha,
}) {
  final (Color? cloth, double length) = switch (outfit) {
    BeanOutfit.varsity => (_cream, 0.86),
    BeanOutfit.hoodie => (_lavender, 0.86),
    BeanOutfit.sweater => (_navy, 0.86),
    BeanOutfit.vest || BeanOutfit.none => (null, 0.0),
  };
  if (cloth == null) return;
  Paint stroke(Color c, double w) => Paint()
    ..color = c.withValues(alpha: c.a * alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
  final end = Offset.lerp(shoulder, hand, length)!;
  canvas.drawLine(shoulder, end, stroke(cloth, width * 2.7));
  // The cuff: a band at the end of the sleeve.
  final cuffFrom = Offset.lerp(shoulder, hand, length - 0.12)!;
  final cuff = switch (outfit) {
    BeanOutfit.varsity => _navy,
    BeanOutfit.hoodie => _lavenderDark,
    _ => _shade(cloth, 0.25),
  };
  canvas.drawLine(cuffFrom, end, stroke(cuff, width * 2.7));
  if (outfit == BeanOutfit.varsity) {
    final stripe = Offset.lerp(shoulder, hand, length - 0.06)!;
    canvas.drawCircle(
      stripe,
      width * 0.42,
      Paint()..color = _cream.withValues(alpha: alpha),
    );
  }
}

/// [outfit] on a body of [bodyPath] inside [body], from [neckY] down.
void paintOutfit(
  Canvas canvas,
  BeanOutfit outfit,
  Path bodyPath,
  Rect body, {
  required Color bodyColor,
  required double neckY,
  required bool facingRight,
  required double alpha,
}) {
  if (outfit == BeanOutfit.none) return;
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  Paint stroke(Color c, double w) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
  final w = body.width;
  final cx = body.center.dx;
  final hemY = body.top + body.height * 0.86;
  final dir = facingRight ? 1.0 : -1.0;

  // Clothes stand a little proud of the body, so they read as worn.
  final grow = Matrix4.identity()
    ..translateByDouble(cx, body.center.dy, 0, 1)
    ..scaleByDouble(1.05, 1.0, 1, 1)
    ..translateByDouble(-cx, -body.center.dy, 0, 1);
  final outline = bodyPath.transform(grow.storage);
  Path band(double top, double bottom) => Path.combine(
    PathOperation.intersect,
    outline,
    Path()..addRect(Rect.fromLTRB(body.left - w, top, body.right + w, bottom)),
  );
  final torso = band(neckY, hemY);
  final torsoBounds = torso.getBounds();
  // The neckline follows the round of the body a little below the chin.
  final neckline = Path()
    ..moveTo(torsoBounds.left, neckY + w * 0.02)
    ..quadraticBezierTo(
      cx,
      neckY + w * 0.1,
      torsoBounds.right,
      neckY + w * 0.02,
    );

  switch (outfit) {
    case BeanOutfit.none:
      return;

    case BeanOutfit.varsity:
      canvas.drawPath(torso, fill(_navy));
      // Open at the front: the body shows in a narrow V.
      final open = Path.combine(
        PathOperation.intersect,
        torso,
        Path()
          ..moveTo(cx - w * 0.05, neckY)
          ..lineTo(cx + w * 0.05, neckY)
          ..lineTo(cx + w * 0.09, hemY)
          ..lineTo(cx - w * 0.09, hemY)
          ..close(),
      );
      canvas.drawPath(open, fill(bodyColor));
      for (final side in const [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(cx + side * w * 0.055, neckY + w * 0.02),
          Offset(cx + side * w * 0.095, hemY - w * 0.02),
          stroke(_cream, w * 0.022),
        );
      }
      // Ribbed collar and hem, each with two white stripes.
      canvas.drawPath(neckline, stroke(_navy, w * 0.07));
      canvas.drawPath(
        neckline.shift(Offset(0, -w * 0.012)),
        stroke(_cream, w * 0.014),
      );
      final hem = band(hemY - w * 0.09, hemY);
      canvas.drawPath(hem, fill(_shade(_navy, 0.12)));
      for (final y in [hemY - w * 0.065, hemY - w * 0.035]) {
        canvas.save();
        canvas.clipPath(hem);
        canvas.drawLine(
          Offset(body.left - w, y),
          Offset(body.right + w, y),
          stroke(_cream, w * 0.012),
        );
        canvas.restore();
      }

    case BeanOutfit.hoodie:
      canvas.drawPath(torso, fill(_lavender));
      // The hood lies around the neck as a thick soft roll.
      canvas.drawPath(neckline, stroke(_lavenderLight, w * 0.11));
      // Drawstrings with little tips.
      for (final side in const [-1.0, 1.0]) {
        final from = Offset(cx + side * w * 0.07, neckY + w * 0.1);
        final to = from.translate(side * w * 0.01, w * 0.16);
        canvas.drawLine(from, to, stroke(_cream, w * 0.022));
        canvas.drawCircle(to, w * 0.022, fill(_cream));
      }
      // The kangaroo pocket.
      final pocketTop = neckY + (hemY - neckY) * 0.55;
      final pocketBottom = hemY - w * 0.06;
      canvas.drawPath(
        Path.combine(
          PathOperation.intersect,
          torso,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                cx - w * 0.24,
                pocketTop,
                cx + w * 0.24,
                pocketBottom,
              ),
              Radius.circular(w * 0.05),
            ),
          ),
        ),
        fill(_lavenderDark),
      );
      final hem = band(hemY - w * 0.05, hemY);
      canvas.drawPath(hem, fill(_lavenderDark));

    case BeanOutfit.sweater:
      canvas.drawPath(torso, fill(_navy));
      final mid = neckY + (hemY - neckY) * 0.42;
      canvas.drawPath(band(mid, mid + (hemY - neckY) * 0.22), fill(_cream));
      // Ribbed collar and hem.
      canvas.drawPath(neckline, stroke(_shade(_navy, 0.15), w * 0.07));
      final hem = band(hemY - w * 0.08, hemY);
      canvas.drawPath(hem, fill(_shade(_navy, 0.15)));
      canvas.save();
      canvas.clipPath(hem);
      for (var x = body.left; x < body.right; x += w * 0.06) {
        canvas.drawLine(
          Offset(x, hemY - w * 0.08),
          Offset(x, hemY),
          stroke(_navy, w * 0.014),
        );
      }
      canvas.restore();

    case BeanOutfit.vest:
      // A light utility vest open at the front, with a pocket.
      final gapTop = w * 0.07;
      final gapBottom = w * 0.12;
      for (final side in const [-1.0, 1.0]) {
        final panel = Path.combine(
          PathOperation.intersect,
          torso,
          Path()
            ..moveTo(cx + side * gapTop, neckY)
            ..lineTo(cx + side * w, neckY)
            ..lineTo(cx + side * w, hemY)
            ..lineTo(cx + side * gapBottom, hemY)
            ..close(),
        );
        canvas.drawPath(panel, fill(_vest));
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - dir * w * 0.3 - w * 0.08,
            neckY + (hemY - neckY) * 0.48,
            w * 0.16,
            w * 0.14,
          ),
          Radius.circular(w * 0.025),
        ),
        fill(_vestDark),
      );
      // The crossbody bag: a strap from the far shoulder to the near hip.
      final strapFrom = Offset(cx - dir * w * 0.3, neckY + w * 0.02);
      final bagCenter = Offset(
        cx + dir * w * 0.36,
        neckY + (hemY - neckY) * 0.62,
      );
      canvas.drawLine(strapFrom, bagCenter, stroke(_bagDark, w * 0.04));
      final bag = RRect.fromRectAndRadius(
        Rect.fromCenter(center: bagCenter, width: w * 0.36, height: w * 0.27),
        Radius.circular(w * 0.06),
      );
      canvas.drawRRect(bag, fill(_bag));
      // The flap and its button.
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(bag.left, bag.top, bag.width, bag.height * 0.45),
          topLeft: Radius.circular(w * 0.06),
          topRight: Radius.circular(w * 0.06),
          bottomLeft: Radius.circular(w * 0.03),
          bottomRight: Radius.circular(w * 0.03),
        ),
        fill(_bagDark),
      );
      canvas.drawCircle(
        Offset(bagCenter.dx, bag.top + bag.height * 0.45),
        math.max(w * 0.025, 1),
        fill(_cream),
      );
  }
}
