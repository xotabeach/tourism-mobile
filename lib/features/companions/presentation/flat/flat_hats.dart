import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/hat_art.dart';

/// The hats of a companion's character (FRONTEND-72, BACKEND-65).
///
/// Flat like the rest of the world: two or three tones each, no outlines,
/// small details (stitches, ribs, a shine) drawn as shapes. Every hat sits
/// on the top of the body rect it is given and scales with its width.
enum BeanHat {
  beanie('beanie'),
  cap('cap'),
  headband('headband'),
  tuft('tuft'),
  panama('panama'),
  strawHat('straw_hat'),
  bandana('bandana'),
  ushanka('ushanka'),
  beret('beret'),
  climbingHelmet('climbing_helmet'),
  cowboy('cowboy'),
  crown('crown'),
  tricorn('tricorn'),
  viking('viking'),
  chef('chef'),
  topHat('top_hat'),
  wreath('wreath'),
  sailor('sailor'),
  wizard('wizard'),
  party('party'),
  headphones('headphones'),
  flatCap('flat_cap'),
  winterHat('winter_hat');

  const BeanHat(this.slug);

  /// The server's name for it.
  final String slug;

  static BeanHat? fromSlug(String? slug) {
    for (final hat in values) {
      if (hat.slug == slug) return hat;
    }
    return null;
  }

  /// The hat an account starts with: one of the four free ones.
  static BeanHat forUser(String userId) {
    var hash = 7;
    for (final unit in userId.codeUnits) {
      hash = (hash * 17 + unit) & 0x7fffffff;
    }
    return values[hash % 4];
  }
}

Color _shade(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;
Color _tint(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

/// Draws [hat] on [body]. [bodyColor] picks contrasting hat colours where
/// the hat has none of its own; [sway] (-1..1) moves loose parts.
void paintHat(
  Canvas canvas,
  BeanHat hat,
  Rect body, {
  required Color bodyColor,
  required double alpha,
  bool facingRight = true,
  double sway = 0,
  double? eyeY,
}) {
  // The designer's drawing where there is one (FRONTEND-79).
  if (eyeY != null &&
      paintHatArt(canvas, hat, body, eyeY: eyeY, alpha: alpha)) {
    return;
  }
  Paint fill(Color c) => Paint()..color = c.withValues(alpha: c.a * alpha);
  Paint line(Color c, double width) => fill(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  final w = body.width;
  final top = body.top;
  final cx = body.center.dx;
  final left = body.left;
  final right = body.right;
  // Where the head's curve meets a brim: always above the eyes, which sit
  // at about a third of the body's height on every shape.
  final shapeBrim = top + math.min(w * 0.3, body.height * 0.19);
  final brimY = eyeY == null ? shapeBrim : math.min(shapeBrim, eyeY - w * 0.27);

  switch (hat) {
    // Drawn only from the designer's art, which needs the eyes.
    case BeanHat.flatCap || BeanHat.winterHat:
      return;

    case BeanHat.beanie:
      // Mustard knit with a pompom of the same yarn (FRONTEND-79).
      const knit = Color(0xFFF0B42C);
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.04, brimY + w * 0.06)
          ..quadraticBezierTo(
            cx,
            top - w * 0.46,
            right - w * 0.04,
            brimY + w * 0.06,
          )
          ..close(),
        fill(knit),
      );
      // Knit ribs on the crown.
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(
          Offset(cx + i * w * 0.14, brimY),
          Offset(cx + i * w * 0.07, top - w * 0.06 + (i.abs() * w * 0.06)),
          line(_shade(knit, 0.07), w * 0.022),
        );
      }
      final cuff = RRect.fromRectAndRadius(
        Rect.fromLTWH(left - w * 0.01, brimY - w * 0.04, w * 1.02, w * 0.2),
        Radius.circular(w * 0.09),
      );
      canvas.drawRRect(cuff, fill(_tint(knit, 0.28)));
      for (var i = 1; i < 8; i++) {
        final x = left + w * i / 8;
        canvas.drawLine(
          Offset(x, brimY - w * 0.01),
          Offset(x, brimY + w * 0.13),
          line(_tint(knit, 0.12), w * 0.02),
        );
      }
      final pom = Offset(cx + sway * w * 0.03, top - w * 0.1);
      canvas.drawCircle(pom, w * 0.13, fill(_shade(knit, 0.08)));
      canvas.drawCircle(
        pom.translate(-w * 0.03, -w * 0.03),
        w * 0.07,
        fill(_tint(knit, 0.18)),
      );

    case BeanHat.cap:
      // A coral baseball cap snug on the head, the peak forward (owner's
      // sketch, FRONTEND-79).
      const cap = Color(0xFFF2654F);
      final dir = facingRight ? 1.0 : -1.0;
      final crownBottom = brimY + w * 0.08;
      // Worn a little askew, the peak dipping toward where it points.
      canvas.save();
      canvas.translate(cx, top);
      canvas.rotate(dir * 0.12);
      canvas.translate(-cx, -top);
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.02, crownBottom)
          ..cubicTo(
            left + w * 0.02,
            top - w * 0.2,
            right - w * 0.02,
            top - w * 0.2,
            right - w * 0.02,
            crownBottom,
          )
          ..close(),
        fill(cap),
      );
      // A seam and the button on top.
      canvas.drawLine(
        Offset(cx, top - w * 0.1),
        Offset(cx - dir * w * 0.06, crownBottom),
        line(_shade(cap, 0.12), w * 0.018),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, top - w * 0.1),
          width: w * 0.1,
          height: w * 0.06,
        ),
        fill(_shade(cap, 0.15)),
      );
      // The peak: a flat curved visor out to the side it faces.
      canvas.drawPath(
        Path()
          ..moveTo(cx + dir * w * 0.1, crownBottom - w * 0.06)
          ..quadraticBezierTo(
            cx + dir * w * 0.62,
            crownBottom - w * 0.1,
            cx + dir * w * 0.74,
            crownBottom + w * 0.02,
          )
          ..quadraticBezierTo(
            cx + dir * w * 0.45,
            crownBottom + w * 0.07,
            cx + dir * w * 0.1,
            crownBottom + w * 0.03,
          )
          ..close(),
        fill(_shade(cap, 0.14)),
      );
      canvas.restore();

    case BeanHat.headband:
      const band = Color(0xFFFF6B6B);
      canvas.drawRect(
        Rect.fromLTWH(left, top + w * 0.18, w, w * 0.14),
        fill(band),
      );
      canvas.drawRect(
        Rect.fromLTWH(left, top + w * 0.235, w, w * 0.03),
        fill(const Color(0xFFFFF6E5)),
      );
      final leaf = Offset(right - w * 0.12, top + w * 0.06);
      canvas.save();
      canvas.translate(leaf.dx, leaf.dy);
      canvas.rotate(0.35 + sway * 0.15);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.18, height: w * 0.34),
        fill(const Color(0xFF34C759)),
      );
      canvas.drawLine(
        Offset(0, -w * 0.14),
        Offset(0, w * 0.14),
        line(const Color(0xFF1F8A3E), w * 0.02),
      );
      canvas.restore();

    case BeanHat.tuft:
      final hair = _shade(bodyColor, 0.38);
      for (var i = -1; i <= 1; i++) {
        final base = Offset(cx + i * w * 0.1, top + w * 0.05);
        final tip = base.translate(
          i * w * 0.16 + sway * w * 0.06,
          -w * 0.3 - (i == 0 ? w * 0.06 : 0),
        );
        canvas.drawPath(
          Path()
            ..moveTo(base.dx, base.dy)
            ..quadraticBezierTo(
              base.dx + i * w * 0.02,
              (base.dy + tip.dy) / 2,
              tip.dx,
              tip.dy,
            )
            ..quadraticBezierTo(
              tip.dx + w * 0.07,
              tip.dy + w * 0.02,
              tip.dx + w * 0.04,
              tip.dy + w * 0.08,
            ),
          line(hair, w * 0.055),
        );
      }

    case BeanHat.panama:
      // A mint bucket hat: a round crown and a brim sloping down.
      const cloth = Color(0xFF8ED8C0);
      final band = brimY + w * 0.02;
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.16, band + w * 0.14)
          ..quadraticBezierTo(
            cx,
            band - w * 0.12,
            right + w * 0.16,
            band + w * 0.14,
          )
          ..quadraticBezierTo(
            cx,
            band + w * 0.04,
            left - w * 0.16,
            band + w * 0.14,
          )
          ..close(),
        fill(_shade(cloth, 0.1)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.06, band + w * 0.02)
          ..cubicTo(
            left + w * 0.04,
            top - w * 0.26,
            right - w * 0.04,
            top - w * 0.26,
            right - w * 0.06,
            band + w * 0.02,
          )
          ..quadraticBezierTo(
            cx,
            band + w * 0.07,
            left + w * 0.06,
            band + w * 0.02,
          )
          ..close(),
        fill(cloth),
      );
      // Stitching rings on the brim.
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.08, band + w * 0.11)
          ..quadraticBezierTo(
            cx,
            band - w * 0.04,
            right + w * 0.08,
            band + w * 0.11,
          ),
        line(_tint(cloth, 0.3), w * 0.012),
      );

    case BeanHat.strawHat:
      const straw = Color(0xFFF2C94C);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, brimY + w * 0.04),
          width: w * 1.7,
          height: w * 0.32,
        ),
        fill(_shade(straw, 0.06)),
      );
      for (var i = 1; i <= 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, brimY + w * 0.04),
            width: w * (1.7 - i * 0.28),
            height: w * (0.32 - i * 0.05),
          ),
          line(_shade(straw, 0.22), w * 0.015),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.14, brimY + w * 0.02)
          ..quadraticBezierTo(
            cx,
            top - w * 0.36,
            right - w * 0.14,
            brimY + w * 0.02,
          )
          ..close(),
        fill(straw),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.15, brimY - w * 0.1, w * 0.7, w * 0.09),
        fill(const Color(0xFFE5484D)),
      );

    case BeanHat.bandana:
      const cloth = Color(0xFFE5484D);
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.02, brimY + w * 0.02)
          ..quadraticBezierTo(
            cx,
            top - w * 0.32,
            right + w * 0.02,
            brimY + w * 0.02,
          )
          ..quadraticBezierTo(
            cx,
            brimY - w * 0.06,
            left - w * 0.02,
            brimY + w * 0.02,
          ),
        fill(cloth),
      );
      for (final (dx, dy) in const [
        (-0.2, 0.02),
        (0.05, -0.06),
        (0.25, 0.04),
        (-0.05, 0.14),
        (0.18, 0.18),
      ]) {
        canvas.drawCircle(
          Offset(cx + dx * w, top + dy * w + w * 0.04),
          w * 0.035,
          fill(const Color(0xFFFFF6E5)),
        );
      }
      final knot = Offset(right - w * 0.02, brimY - w * 0.02);
      for (final (dx, dy) in [
        (0.32, 0.12 + sway * 0.04),
        (0.26, 0.3 + sway * 0.05),
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(knot.dx, knot.dy - w * 0.04)
            ..lineTo(knot.dx + dx * w, knot.dy + dy * w)
            ..lineTo(knot.dx + dx * w * 0.6, knot.dy + dy * w + w * 0.08)
            ..close(),
          fill(_shade(cloth, 0.12)),
        );
      }
      canvas.drawCircle(knot, w * 0.07, fill(_shade(cloth, 0.2)));

    case BeanHat.ushanka:
      const fur = Color(0xFF8A5A33);
      const furLight = Color(0xFFC59A6D);
      for (final side in const [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                cx + side * w * 0.48,
                brimY + w * 0.22 + sway * w * 0.02,
              ),
              width: w * 0.24,
              height: w * 0.46,
            ),
            Radius.circular(w * 0.1),
          ),
          fill(furLight),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.04, brimY + w * 0.06)
          ..quadraticBezierTo(
            cx,
            top - w * 0.42,
            right + w * 0.04,
            brimY + w * 0.06,
          )
          ..close(),
        fill(fur),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left - w * 0.06, brimY - w * 0.06, w * 1.12, w * 0.2),
          Radius.circular(w * 0.1),
        ),
        fill(furLight),
      );
      _star(
        canvas,
        Offset(cx, top - w * 0.02),
        w * 0.08,
        fill(const Color(0xFFE5484D)),
      );

    case BeanHat.beret:
      const felt = Color(0xFF2E3A59);
      canvas.save();
      canvas.translate(cx + w * 0.06, top + w * 0.02);
      canvas.rotate(-0.18);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 1.2, height: w * 0.42),
        fill(felt),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-w * 0.16, -w * 0.06),
          width: w * 0.44,
          height: w * 0.14,
        ),
        fill(_tint(felt, 0.15)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.02, -w * 0.24),
            width: w * 0.06,
            height: w * 0.12,
          ),
          Radius.circular(w * 0.03),
        ),
        fill(felt),
      );
      canvas.restore();

    case BeanHat.climbingHelmet:
      const shell = Color(0xFFFF8C1A);
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.02, brimY + w * 0.06)
          ..quadraticBezierTo(
            cx,
            top - w * 0.42,
            right + w * 0.02,
            brimY + w * 0.06,
          )
          ..close(),
        fill(shell),
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + i * w * 0.2, top - w * 0.02),
              width: w * 0.08,
              height: w * 0.18,
            ),
            Radius.circular(w * 0.04),
          ),
          fill(_shade(shell, 0.3)),
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(left - w * 0.02, brimY + w * 0.02, w * 1.04, w * 0.06),
        fill(const Color(0xFF2E3A59)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, brimY - w * 0.04),
            width: w * 0.22,
            height: w * 0.14,
          ),
          Radius.circular(w * 0.04),
        ),
        fill(const Color(0xFF2E3A59)),
      );
      canvas.drawCircle(
        Offset(cx, brimY - w * 0.04),
        w * 0.045,
        fill(const Color(0xFFFFE66D)),
      );

    case BeanHat.cowboy:
      const leather = Color(0xFFA0623A);
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.4, brimY - w * 0.12)
          ..quadraticBezierTo(
            left - w * 0.2,
            brimY + w * 0.12,
            cx,
            brimY + w * 0.08,
          )
          ..quadraticBezierTo(
            right + w * 0.2,
            brimY + w * 0.12,
            right + w * 0.4,
            brimY - w * 0.12,
          )
          ..quadraticBezierTo(
            cx,
            brimY + w * 0.02,
            left - w * 0.4,
            brimY - w * 0.12,
          ),
        fill(_shade(leather, 0.12)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.1, brimY + w * 0.02)
          ..lineTo(left + w * 0.16, top - w * 0.3)
          ..quadraticBezierTo(
            cx,
            top - w * 0.18,
            right - w * 0.16,
            top - w * 0.3,
          )
          ..lineTo(right - w * 0.1, brimY + w * 0.02)
          ..close(),
        fill(leather),
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.12, top - w * 0.24)
          ..quadraticBezierTo(
            cx,
            top - w * 0.12,
            cx + w * 0.12,
            top - w * 0.24,
          ),
        line(_shade(leather, 0.25), w * 0.03),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.11, brimY - w * 0.1, w * 0.78, w * 0.08),
        fill(const Color(0xFF3A2414)),
      );

    case BeanHat.crown:
      const gold = Color(0xFFFFC145);
      final base = brimY;
      final points = Path()
        ..moveTo(left + w * 0.04, base)
        ..lineTo(left + w * 0.04, top - w * 0.16)
        ..lineTo(left + w * 0.27, top + w * 0.04)
        ..lineTo(cx, top - w * 0.26)
        ..lineTo(right - w * 0.27, top + w * 0.04)
        ..lineTo(right - w * 0.04, top - w * 0.16)
        ..lineTo(right - w * 0.04, base)
        ..close();
      canvas.drawPath(points, fill(gold));
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.04, base - w * 0.12, w * 0.92, w * 0.12),
        fill(_shade(gold, 0.15)),
      );
      for (final (dx, color) in const [
        (-0.27, Color(0xFF4CC3D9)),
        (0.0, Color(0xFFE5484D)),
        (0.27, Color(0xFF7AC74F)),
      ]) {
        canvas.drawCircle(
          Offset(cx + dx * w, base - w * 0.06),
          w * 0.045,
          fill(color),
        );
      }
      for (final tip in [
        Offset(left + w * 0.04, top - w * 0.16),
        Offset(cx, top - w * 0.26),
        Offset(right - w * 0.04, top - w * 0.16),
      ]) {
        canvas.drawCircle(tip, w * 0.04, fill(const Color(0xFFFFF6E5)));
      }
      canvas.drawLine(
        Offset(left + w * 0.16, top - w * 0.02),
        Offset(left + w * 0.22, top + w * 0.08),
        line(_tint(gold, 0.5), w * 0.025),
      );

    case BeanHat.tricorn:
      const felt = Color(0xFF2E2A3B);
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.3, brimY)
          ..quadraticBezierTo(cx, top - w * 0.5, right + w * 0.3, brimY)
          ..quadraticBezierTo(cx, brimY - w * 0.14, left - w * 0.3, brimY),
        fill(felt),
      );
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.3, brimY)
          ..quadraticBezierTo(cx, top - w * 0.5, right + w * 0.3, brimY),
        line(const Color(0xFFFFC145), w * 0.04),
      );
      canvas.save();
      canvas.translate(cx + w * 0.1, top - w * 0.1);
      canvas.rotate(-0.6 + sway * 0.1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.2, 0),
          width: w * 0.5,
          height: w * 0.12,
        ),
        fill(const Color(0xFFF25C54)),
      );
      canvas.restore();
      // A gold button at the front.
      canvas.drawCircle(
        Offset(cx, top + w * 0.04),
        w * 0.05,
        fill(const Color(0xFFFFC145)),
      );

    case BeanHat.viking:
      const steel = Color(0xFFB8C2CC);
      for (final side in const [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(cx + side * w * 0.36, top + w * 0.06)
          ..quadraticBezierTo(
            cx + side * w * 0.78,
            top + w * 0.02,
            cx + side * w * 0.7,
            top - w * 0.42,
          )
          ..quadraticBezierTo(
            cx + side * w * 0.62,
            top - w * 0.06,
            cx + side * w * 0.3,
            top - w * 0.06,
          )
          ..close();
        canvas.drawPath(horn, fill(const Color(0xFFF6EFD9)));
        canvas.drawLine(
          Offset(cx + side * w * 0.6, top - w * 0.02),
          Offset(cx + side * w * 0.66, top - w * 0.12),
          line(const Color(0xFFD9CDAA), w * 0.03),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(left - w * 0.02, brimY + w * 0.06)
          ..quadraticBezierTo(
            cx,
            top - w * 0.4,
            right + w * 0.02,
            brimY + w * 0.06,
          )
          ..close(),
        fill(steel),
      );
      canvas.drawRect(
        Rect.fromLTWH(left - w * 0.02, brimY - w * 0.02, w * 1.04, w * 0.09),
        fill(_shade(steel, 0.25)),
      );
      canvas.drawRect(
        Rect.fromLTWH(cx - w * 0.04, top - w * 0.1, w * 0.08, w * 0.4),
        fill(_shade(steel, 0.25)),
      );
      for (var i = -2; i <= 2; i++) {
        canvas.drawCircle(
          Offset(cx + i * w * 0.2, brimY + w * 0.025),
          w * 0.025,
          fill(_tint(steel, 0.5)),
        );
      }

    case BeanHat.chef:
      const white = Color(0xFFFFFFFF);
      for (final (dx, dy, r) in const [
        (-0.24, -0.22, 0.24),
        (0.24, -0.22, 0.24),
        (0.0, -0.36, 0.28),
      ]) {
        canvas.drawCircle(
          Offset(cx + dx * w, top + dy * w),
          r * w,
          fill(white),
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.08, top - w * 0.28, w * 0.84, w * 0.42),
        fill(white),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + w * 0.04, brimY - w * 0.12, w * 0.92, w * 0.16),
          Radius.circular(w * 0.05),
        ),
        fill(const Color(0xFFE9EEF3)),
      );
      for (var i = 1; i < 4; i++) {
        canvas.drawLine(
          Offset(left + w * i / 4, top - w * 0.2),
          Offset(left + w * i / 4, brimY - w * 0.12),
          line(const Color(0xFFE2E8EE), w * 0.02),
        );
      }

    case BeanHat.topHat:
      const silk = Color(0xFF1B1B2F);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, brimY),
          width: w * 1.25,
          height: w * 0.22,
        ),
        fill(silk),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + w * 0.14, top - w * 0.62, w * 0.72, w * 0.92),
          Radius.circular(w * 0.06),
        ),
        fill(silk),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.14, brimY - w * 0.22, w * 0.72, w * 0.12),
        fill(const Color(0xFFE5484D)),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.22, top - w * 0.56, w * 0.07, w * 0.5),
        fill(const Color(0x33FFFFFF)),
      );

    case BeanHat.wreath:
      for (var i = 0; i < 9; i++) {
        final a = math.pi + i / 8 * math.pi;
        final at = Offset(
          cx + math.cos(a) * w * 0.5,
          brimY - w * 0.08 + math.sin(a) * w * 0.26,
        );
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(a + math.pi / 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * 0.12,
            height: w * 0.24,
          ),
          fill(i.isEven ? const Color(0xFF34C759) : const Color(0xFF2E9E4F)),
        );
        canvas.restore();
      }
      for (final (i, color) in const [
        (2, Color(0xFFFF8FB1)),
        (4, Color(0xFFFFE66D)),
        (6, Color(0xFFB388EB)),
      ]) {
        final a = math.pi + i / 8 * math.pi;
        final at = Offset(
          cx + math.cos(a) * w * 0.5,
          brimY - w * 0.08 + math.sin(a) * w * 0.26,
        );
        for (var p = 0; p < 5; p++) {
          final pa = p / 5 * math.pi * 2;
          canvas.drawCircle(
            at.translate(math.cos(pa) * w * 0.05, math.sin(pa) * w * 0.05),
            w * 0.045,
            fill(color),
          );
        }
        canvas.drawCircle(at, w * 0.035, fill(const Color(0xFFFFC145)));
      }

    case BeanHat.sailor:
      const white = Color(0xFFFFFFFF);
      const navy = Color(0xFF1F3A68);
      // Ribbons fly at the back.
      for (final off in const [0.0, 0.1]) {
        canvas.drawPath(
          Path()
            ..moveTo(left + w * 0.1, brimY)
            ..lineTo(
              left - w * (0.24 + off) + sway * w * 0.05,
              brimY + w * (0.34 + off),
            )
            ..lineTo(
              left - w * (0.14 + off) + sway * w * 0.05,
              brimY + w * (0.38 + off),
            )
            ..lineTo(left + w * 0.2, brimY + w * 0.02)
            ..close(),
          fill(navy),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, top - w * 0.04),
          width: w * 1.15,
          height: w * 0.36,
        ),
        fill(white),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.02, top + w * 0.08, w * 0.96, w * 0.16),
        fill(navy),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + w * 0.02, top + w * 0.14, w * 0.96, w * 0.02),
        fill(const Color(0xFFFFC145)),
      );
      canvas.drawCircle(Offset(cx, top - w * 0.06), w * 0.04, fill(navy));

    case BeanHat.wizard:
      const purple = Color(0xFF6C4AB6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, brimY),
          width: w * 1.3,
          height: w * 0.24,
        ),
        fill(_shade(purple, 0.15)),
      );
      final tip = Offset(cx + w * 0.3 + sway * w * 0.06, top - w * 0.95);
      canvas.drawPath(
        Path()
          ..moveTo(left + w * 0.1, brimY)
          ..quadraticBezierTo(cx - w * 0.05, top - w * 0.3, tip.dx, tip.dy)
          ..quadraticBezierTo(
            cx + w * 0.15,
            top - w * 0.3,
            right - w * 0.1,
            brimY,
          )
          ..close(),
        fill(purple),
      );
      _star(
        canvas,
        Offset(cx - w * 0.05, top - w * 0.1),
        w * 0.08,
        fill(const Color(0xFFFFE66D)),
      );
      _star(
        canvas,
        Offset(cx + w * 0.12, top - w * 0.42),
        w * 0.05,
        fill(const Color(0xFFFFE66D)),
      );
      canvas.drawCircle(
        Offset(cx + w * 0.2, top + w * 0.08),
        w * 0.03,
        fill(const Color(0xFFFFE66D)),
      );

    case BeanHat.party:
      final apex = Offset(cx + sway * w * 0.04, top - w * 0.78);
      final cone = Path()
        ..moveTo(left + w * 0.16, brimY)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(right - w * 0.16, brimY)
        ..close();
      canvas.drawPath(cone, fill(const Color(0xFF4CC3D9)));
      canvas.save();
      canvas.clipPath(cone);
      for (var i = 0; i < 5; i++) {
        final y = brimY - i * w * 0.24;
        canvas.drawPath(
          Path()
            ..moveTo(left, y)
            ..lineTo(right, y - w * 0.18)
            ..lineTo(right, y - w * 0.28)
            ..lineTo(left, y - w * 0.1)
            ..close(),
          fill(const Color(0xFFFF8FB1)),
        );
      }
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(
            left + w * (0.3 + (i % 3) * 0.2),
            brimY - w * (0.15 + (i ~/ 3) * 0.3),
          ),
          w * 0.025,
          fill(const Color(0xFFFFE66D)),
        );
      }
      canvas.restore();
      canvas.drawCircle(apex, w * 0.1, fill(const Color(0xFFFFC145)));
      for (var i = 0; i < 6; i++) {
        final a = i / 6 * math.pi * 2;
        canvas.drawLine(
          apex,
          apex.translate(math.cos(a) * w * 0.14, math.sin(a) * w * 0.14),
          line(const Color(0xFFFFC145), w * 0.02),
        );
      }

    case BeanHat.headphones:
      // Over the head from ear to ear, the cups at eye level, a little
      // outside the body (the owner's sketch, FRONTEND-79).
      const cup = Color(0xFF1E3A78);
      final cupY = (eyeY ?? brimY + w * 0.2) - w * 0.04;
      final reach = w * 0.5 + w * 0.04;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, cupY),
          width: reach * 2,
          height: (cupY - top) * 2 + w * 0.2,
        ),
        math.pi * 1.04,
        math.pi * 0.92,
        false,
        line(_shade(cup, 0.1), w * 0.06),
      );
      for (final side in const [-1.0, 1.0]) {
        final at = Offset(cx + side * reach, cupY);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: at, width: w * 0.2, height: w * 0.32),
            Radius.circular(w * 0.1),
          ),
          fill(cup),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: at.translate(-side * w * 0.06, 0),
              width: w * 0.08,
              height: w * 0.26,
            ),
            Radius.circular(w * 0.04),
          ),
          fill(_tint(cup, 0.18)),
        );
      }
  }
}

void _star(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), paint);
}
