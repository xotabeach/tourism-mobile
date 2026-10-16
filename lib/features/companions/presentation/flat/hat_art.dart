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
void paintHatArtIn(Canvas canvas, BeanHat hat, Rect rect) {
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
    canvas.drawPath(path, Paint()..color = color);
  }
  canvas.restore();
}
