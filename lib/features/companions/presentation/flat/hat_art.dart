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

/// How a drawn hat sits on a head: its width against the body's width,
/// which point of the drawing goes over the middle of the head, and where
/// its lower edge falls against the eyes, in body widths (positive is
/// below the middle of the eyes).
class _Fit {
  const _Fit(this.width, this.bottom, {this.anchor = 0.5});

  final double width;
  final double bottom;
  final double anchor;
}

// Fitted against the designer's dressed characters (owner, 2026-10-16:
// the first fit made every hat far too big).
const _fits = <BeanHat, _Fit>{
  BeanHat.bandana: _Fit(0.85, -0.15, anchor: 0.42),
  BeanHat.cap: _Fit(0.78, -0.19, anchor: 0.58),
  BeanHat.flatCap: _Fit(0.8, -0.17),
  BeanHat.headphones: _Fit(1.1, 0.12),
  BeanHat.panama: _Fit(0.95, -0.1),
  BeanHat.sailor: _Fit(0.8, -0.17),
  BeanHat.beanie: _Fit(0.72, -0.16),
  BeanHat.strawHat: _Fit(1.1, -0.2),
  BeanHat.ushanka: _Fit(0.9, 0.1),
  BeanHat.winterHat: _Fit(0.78, -0.16),
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
  required double eyeY,
  double alpha = 1,
}) {
  final data = _hats[hat];
  final fit = _fits[hat];
  if (data == null || fit == null) return false;
  final parts = _cache.putIfAbsent(
    hat,
    () => [for (final (color, d) in data.parts) (color, parseSvgPath(d))],
  );
  final w = body.width;
  final width = w * fit.width;
  final scale = width / data.size.width;
  final height = data.size.height * scale;
  final left = body.center.dx - width * fit.anchor;
  final top = eyeY + w * fit.bottom - height;
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
