import 'dart:math' as math;
import 'dart:ui';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_art.dart'
    show parseSvgPath;
import 'package:tourism_mobile/features/companions/presentation/flat/flat_hats.dart'
    show BeanHat;

part 'hat_art_data.dart';

/// A hat the designer drew (FRONTEND-79): flat parts in the drawing's own
/// units, bottom to top as in the SVG.
class HatArtData {
  const HatArtData({required this.size, required this.parts});

  final Size size;
  final List<(Color, String)> parts;
}

/// How a drawn hat sits on a head (owner, 2026-10-16: fitted to each
/// character's own head, not to the body's widest point).
///
/// [seat] is where the hat meets the head, as a share of the drawing's
/// height: the edge of a cuff, a band, the bottom of a crown. [from]..[to]
/// is the part of the drawing's width at that line that wraps the head; it
/// is made as wide as the head is there, a little more ([snug]). [above]
/// says where that line falls: how far above the top of the eyes, in eye
/// heights (negative is below).
class _Fit {
  const _Fit({
    required this.seat,
    required this.from,
    required this.to,
    required this.above,
    this.snug = 1.04,
  });

  final double seat;
  final double from;
  final double to;
  final double above;
  final double snug;
}

// Measured on the designer's SVGs: where each hat meets the head and how
// much of its width wraps it.
const _fits = <BeanHat, _Fit>{
  BeanHat.bandana: _Fit(seat: 0.85, from: 0.02, to: 0.86, above: 0.5, snug: 1),
  BeanHat.cap: _Fit(seat: 0.84, from: 0.24, to: 0.99, above: 0.6, snug: 1),
  BeanHat.flatCap: _Fit(seat: 0.88, from: 0.04, to: 0.95, above: 0.55, snug: 1),
  BeanHat.headphones: _Fit(
    seat: 0.7,
    from: 0.15,
    to: 0.85,
    above: -0.5,
    snug: 1.02,
  ),
  BeanHat.panama: _Fit(seat: 0.72, from: 0.09, to: 0.91, above: 0.6, snug: 1),
  BeanHat.sailor: _Fit(seat: 0.97, from: 0.1, to: 0.89, above: 0.5, snug: 1),
  BeanHat.beanie: _Fit(seat: 0.93, from: 0.03, to: 0.97, above: 0.5, snug: 1),
  // A pith helmet, its brim a little wider than the head where it rests
  // (the designer's card).
  BeanHat.strawHat: _Fit(seat: 0.85, from: 0, to: 1, above: 0.6, snug: 1.22),
  BeanHat.ushanka: _Fit(seat: 0.6, from: 0.12, to: 0.88, above: 0.55, snug: 1),
  BeanHat.winterHat: _Fit(
    seat: 0.92,
    from: 0.02,
    to: 0.97,
    above: 0.5,
    snug: 1,
  ),
};

/// Where one build needs its own fit: its head is narrower or rounder
/// than the others' (owner, 2026-10-16), keyed by the build's slug.
const _fitsFor = <(BeanHat, String), _Fit>{
  // The green one's head is narrow and long: caps a size down.
  (BeanHat.cap, 'tall'): _Fit(
    seat: 0.84,
    from: 0.24,
    to: 0.99,
    above: 0.5,
    snug: 0.92,
  ),
  (BeanHat.flatCap, 'tall'): _Fit(
    seat: 0.88,
    from: 0.04,
    to: 0.95,
    above: 0.45,
    snug: 0.94,
  ),
};

/// Where each drawn hat sits on each build, in the build's drawing units:
/// measured on the designer's examples of every hat on every character
/// (owner, 2026-10-16). The winter hat sits as the beanie: the same cuff.
const _placed = <(BeanHat, String), Rect>{
  (BeanHat.bandana, 'pin'): Rect.fromLTWH(26.0, -64.6, 355.7, 183.1),
  (BeanHat.bandana, 'round'): Rect.fromLTWH(38.3, -56.8, 354.7, 182.6),
  (BeanHat.bandana, 'small'): Rect.fromLTWH(23.9, -27.6, 205.7, 105.9),
  (BeanHat.bandana, 'tall'): Rect.fromLTWH(17.6, -62.6, 355.1, 182.8),
  (BeanHat.beanie, 'pin'): Rect.fromLTWH(-2.3, -185.6, 345.8, 304.5),
  (BeanHat.beanie, 'round'): Rect.fromLTWH(10.9, -183.4, 345.3, 304.1),
  (BeanHat.beanie, 'small'): Rect.fromLTWH(9.9, -108.4, 196.1, 172.7),
  (BeanHat.beanie, 'tall'): Rect.fromLTWH(-10.6, -189.4, 346.3, 305.0),
  (BeanHat.cap, 'pin'): Rect.fromLTWH(-4.4, -96.3, 308.9, 185.2),
  (BeanHat.cap, 'round'): Rect.fromLTWH(5.7, -93.1, 309.7, 185.6),
  (BeanHat.cap, 'small'): Rect.fromLTWH(6.0, -58.6, 175.3, 105.0),
  (BeanHat.cap, 'tall'): Rect.fromLTWH(-11.2, -94.2, 307.9, 184.5),
  (BeanHat.flatCap, 'pin'): Rect.fromLTWH(8.3, -87.3, 322.8, 185.0),
  (BeanHat.flatCap, 'round'): Rect.fromLTWH(16.8, -88.4, 321.2, 184.1),
  (BeanHat.flatCap, 'small'): Rect.fromLTWH(14.5, -52.4, 176.5, 101.1),
  (BeanHat.flatCap, 'tall'): Rect.fromLTWH(-1.1, -90.7, 323.6, 185.5),
  (BeanHat.headphones, 'pin'): Rect.fromLTWH(-23.8, -51.4, 384.8, 248.0),
  (BeanHat.headphones, 'round'): Rect.fromLTWH(-9.5, -51.2, 383.4, 247.1),
  (BeanHat.headphones, 'small'): Rect.fromLTWH(-4.5, -33.3, 224.3, 144.6),
  (BeanHat.headphones, 'tall'): Rect.fromLTWH(-29.2, -52.4, 384.5, 247.9),
  (BeanHat.panama, 'pin'): Rect.fromLTWH(34.2, -82.7, 270.8, 168.8),
  (BeanHat.panama, 'round'): Rect.fromLTWH(46.3, -76.8, 270.1, 168.4),
  (BeanHat.panama, 'small'): Rect.fromLTWH(30.5, -43.9, 153.7, 95.8),
  (BeanHat.panama, 'tall'): Rect.fromLTWH(26.8, -79.5, 271.2, 169.0),
  (BeanHat.sailor, 'pin'): Rect.fromLTWH(10.4, -63.7, 315.6, 149.0),
  (BeanHat.sailor, 'round'): Rect.fromLTWH(23.2, -60.4, 315.6, 149.1),
  (BeanHat.sailor, 'small'): Rect.fromLTWH(21.7, -36.8, 171.1, 80.8),
  (BeanHat.sailor, 'tall'): Rect.fromLTWH(4.7, -67.0, 315.7, 149.1),
  (BeanHat.strawHat, 'pin'): Rect.fromLTWH(40.2, -50.5, 263.3, 111.2),
  (BeanHat.strawHat, 'round'): Rect.fromLTWH(49.4, -46.2, 264.9, 111.9),
  (BeanHat.strawHat, 'small'): Rect.fromLTWH(32.7, -25.5, 149.3, 63.0),
  (BeanHat.strawHat, 'tall'): Rect.fromLTWH(33.8, -49.8, 261.7, 110.5),
  (BeanHat.ushanka, 'pin'): Rect.fromLTWH(12.2, -84.3, 314.7, 259.6),
  (BeanHat.ushanka, 'round'): Rect.fromLTWH(19.2, -83.5, 327.2, 269.9),
  (BeanHat.ushanka, 'small'): Rect.fromLTWH(15.8, -36.9, 184.0, 151.8),
  (BeanHat.ushanka, 'tall'): Rect.fromLTWH(7.3, -83.2, 314.1, 259.1),
  (BeanHat.winterHat, 'pin'): Rect.fromLTWH(-2.3, -99.5, 345.8, 218.4),
  (BeanHat.winterHat, 'round'): Rect.fromLTWH(10.9, -97.4, 345.3, 218.1),
  (BeanHat.winterHat, 'small'): Rect.fromLTWH(9.9, -59.6, 196.1, 123.9),
  (BeanHat.winterHat, 'tall'): Rect.fromLTWH(-10.6, -103.2, 346.3, 218.8),
};

final _cache = <BeanHat, List<(Color, Path)>>{};

/// Whether the designer drew [hat]; the others are still drawn in code.
bool hasHatArt(BeanHat hat) => _hats.containsKey(hat);

/// Draws the designer's [hat] on a head whose body is [body], with the
/// eyes at [eyeY]. Returns false when there is no drawing for it.
bool paintHatArt(
  Canvas canvas,
  BeanHat hat,
  Rect body, {
  required Rect eyes,
  required double Function(double y) headHalfWidth,
  String? shape,
  double alpha = 1,
}) {
  final placed = _placed[(hat, shape ?? '')];
  if (placed != null) {
    paintHatArtIn(canvas, hat, placed, alpha: alpha);
    return true;
  }
  final data = _hats[hat];
  final fit = _fitsFor[(hat, shape ?? '')] ?? _fits[hat];
  if (data == null || fit == null) return false;
  final parts = _cache.putIfAbsent(
    hat,
    () => [for (final (color, d) in data.parts) (color, parseSvgPath(d))],
  );
  final lineY = eyes.top - fit.above * eyes.height;
  // Never narrower than half the body: the very top of a head is a point.
  final head = math.max(headHalfWidth(lineY) * 2, body.width * 0.5);
  final width = head * fit.snug / (fit.to - fit.from);
  final scale = width / data.size.width;
  final height = data.size.height * scale;
  final left = body.center.dx - width * (fit.from + fit.to) / 2;
  final top = lineY - height * fit.seat;
  canvas.save();
  canvas.translate(left, top);
  canvas.scale(scale);
  for (final (color, path) in parts) {
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * alpha),
    );
  }
  canvas.restore();
  return true;
}

/// Draws the designer's [hat] stretched into [rect], with nothing fitted:
/// for an illustration laid out by hand (the companions card).
void paintHatArtIn(Canvas canvas, BeanHat hat, Rect rect, {double alpha = 1}) {
  final data = _hats[hat];
  if (data == null) return;
  final parts = _cache.putIfAbsent(
    hat,
    () => [for (final (color, d) in data.parts) (color, parseSvgPath(d))],
  );
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / data.size.width, rect.height / data.size.height);
  for (final (color, path) in parts) {
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * alpha),
    );
  }
  canvas.restore();
}
