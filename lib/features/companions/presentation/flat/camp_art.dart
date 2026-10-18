import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_art.dart'
    show parseSvgPath;

part 'camp_art_data.dart';

/// One flat shape of the designer's camp (FRONTEND-86): a path in the
/// layer's own units, its colour, and the soft effects the SVG had as
/// filters: a blur of the shape itself, or a glow round it.
class CampShape {
  const CampShape(
    this.color,
    this.d, {
    this.evenOdd = false,
    this.blur = 0,
    this.glow,
    this.glowBlur = 0,
    this.tag,
  });

  final Color color;
  final String d;
  final bool evenOdd;
  final double blur;
  final Color? glow;
  final double glowBlur;

  /// `flame` and `firelight` are drawn by the animation, not the backdrop.
  final String? tag;
}

/// A star of the sky layer: drawn by the animation, it twinkles.
class CampStar {
  const CampStar(this.x, this.y, this.r, this.color, {this.glow = 0});

  final double x;
  final double y;
  final double r;
  final Color color;
  final double glow;
}

/// A layer: where it sits in the frame and what it holds.
class CampLayer {
  const CampLayer(this.dx, this.dy, this.items);

  final double dx;
  final double dy;
  final List<Object> items;
}

/// The designer's night camp: forest, three tents, a log and a fire
/// (FRONTEND-86). Everything is in the units of a 362×241 frame.
abstract final class CampArt {
  static const frame = Size(362, 241);

  static final _paths = <String, Path>{};
  static Path _path(CampShape shape) {
    final path = _paths.putIfAbsent(shape.d, () => parseSvgPath(shape.d));
    path.fillType = shape.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
    return path;
  }

  /// Where the flames stand: the middle of their base, in frame units.
  static final Offset fireBase = () {
    Rect? box;
    for (final item in _camp.items) {
      if (item is CampShape && item.tag == 'flame') {
        final b = _path(item).getBounds();
        box = box == null ? b : box.expandToInclude(b);
      }
    }
    final b = box!;
    return Offset(_camp.dx + b.center.dx, _camp.dy + b.bottom);
  }();

  /// The bottom of the tree layer: it sways about this line.
  static double get _treesBase => _trees.dy + 150;

  static void _paintShape(Canvas canvas, CampShape shape) {
    final path = _path(shape);
    if (shape.glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = shape.glow!
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shape.glowBlur * 1.6,
          ),
      );
    }
    final paint = Paint()..color = shape.color;
    if (shape.blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shape.blur);
    }
    canvas.drawPath(path, paint);
  }

  static void _paintLayer(
    Canvas canvas,
    CampLayer layer, {
    bool Function(CampShape)? where,
  }) {
    canvas.save();
    canvas.translate(layer.dx, layer.dy);
    for (final item in layer.items) {
      if (item is CampShape && (where == null || where(item))) {
        _paintShape(canvas, item);
      }
    }
    canvas.restore();
  }

  // The still parts, drawn once into pictures and replayed every frame.
  static Picture? _back;
  static Picture? _treesPicture;
  static Picture? _middle;
  static Picture? _frontPicture;

  static Picture _record(void Function(Canvas) draw) {
    final recorder = PictureRecorder();
    draw(Canvas(recorder, Offset.zero & frame));
    return recorder.endRecording();
  }

  static Picture get _backPicture => _back ??= _record((canvas) {
    final sky = Offset.zero & frame;
    canvas.drawRect(
      sky,
      Paint()
        ..shader = Gradient.linear(
          sky.topCenter,
          sky.bottomCenter,
          [for (final (_, c) in _skyStops) c],
          [for (final (s, _) in _skyStops) s],
        ),
    );
  });

  static Picture get _forestPicture => _forestCache ??= _record((canvas) {
    _paintLayer(canvas, _forest);
    _paintLayer(canvas, _hill);
  });
  static Picture? _forestCache;

  static Picture get _treesPic =>
      _treesPicture ??= _record((canvas) => _paintLayer(canvas, _trees));

  static Picture get _middlePicture => _middle ??= _record((canvas) {
    _paintLayer(canvas, _ground);
    _paintLayer(canvas, _grass);
    _paintLayer(canvas, _camp, where: (s) => s.tag == null);
  });

  static Picture get _frontPic =>
      _frontPicture ??= _record((canvas) => _paintLayer(canvas, _front));

  /// Everything behind the people: sky with twinkling stars, the forest,
  /// the swaying trees, the ground and the camp with its burning fire.
  /// [t] runs 0..1 over the scene's six-second loop.
  static void paintBack(Canvas canvas, double t, {bool still = false}) {
    canvas.drawPicture(_backPicture);
    _paintStars(canvas, still ? 0.25 : t);
    canvas.drawPicture(_forestPicture);
    // The near pines lean with the night wind, a degree at most.
    final lean = still ? 0.0 : math.sin(t * math.pi * 2) * 0.012;
    canvas.save();
    canvas.translate(0, _treesBase);
    canvas.transform(_skewX(lean));
    canvas.translate(0, -_treesBase);
    canvas.drawPicture(_treesPic);
    canvas.restore();
    canvas.drawPicture(_middlePicture);
    _paintFire(canvas, still ? 0.25 : t);
  }

  /// The bushes in front of everyone, swaying a little.
  static void paintFront(Canvas canvas, double t, {bool still = false}) {
    final lean = still ? 0.0 : math.sin((t * 2 + 0.3) * math.pi * 2) * 0.02;
    canvas.save();
    canvas.translate(0, frame.height);
    canvas.transform(_skewX(lean));
    canvas.translate(0, -frame.height);
    canvas.drawPicture(_frontPic);
    canvas.restore();
  }

  static Float64List _skewX(double k) =>
      Float64List.fromList([1, 0, 0, 0, k, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  static void _paintStars(Canvas canvas, double t) {
    canvas.save();
    canvas.translate(_stars.dx, _stars.dy);
    var i = 0;
    for (final item in _stars.items) {
      if (item is! CampStar) continue;
      final phase = _seed(i++);
      // Each star on its own slow beat, now and then nearly out.
      final twinkle =
          0.55 + 0.45 * math.sin((t * (2 + phase * 3) + phase) * math.pi * 2);
      final color = item.color.withValues(alpha: item.color.a * twinkle);
      if (item.glow > 0) {
        canvas.drawCircle(
          Offset(item.x, item.y),
          item.r * 1.6,
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, item.glow * 1.4),
        );
      }
      canvas.drawCircle(
        Offset(item.x, item.y),
        item.r * (0.85 + 0.15 * twinkle),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  static void _paintFire(Canvas canvas, double t) {
    final base = fireBase;
    canvas.save();
    canvas.translate(_camp.dx, _camp.dy);
    final local = base - Offset(_camp.dx, _camp.dy);
    for (final item in _camp.items) {
      if (item is! CampShape) continue;
      if (item.tag == 'firelight') {
        // The light on the grass breathes with the flames.
        final pulse = 0.75 + 0.25 * math.sin(t * math.pi * 2 * 6);
        canvas.drawPath(
          _path(item),
          Paint()
            ..color = item.color.withValues(alpha: item.color.a * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, item.blur * 1.4),
        );
      }
    }
    var layer = 0;
    for (final item in _camp.items) {
      if (item is! CampShape || item.tag != 'flame') continue;
      // Each flame stretches, narrows and leans on its own beat, from its
      // base, so the logs stay put.
      final phase = layer++ * 0.37;
      final up = 1 + 0.11 * math.sin((t * 11 + phase) * math.pi * 2);
      final wide = 1 - 0.05 * math.sin((t * 11 + phase + 0.25) * math.pi * 2);
      final lean = 0.08 * math.sin((t * 7 + phase) * math.pi * 2);
      canvas.save();
      canvas.translate(local.dx, local.dy);
      canvas.transform(_skewX(lean));
      canvas.scale(wide, up);
      canvas.translate(-local.dx, -local.dy);
      _paintShape(canvas, item);
      canvas.restore();
    }
    canvas.restore();
    // Sparks fly up, wobble and go out.
    for (var i = 0; i < 12; i++) {
      final life = (t * 2 + _seed(i + 200)) % 1;
      final x =
          base.dx +
          (_seed(i + 210) - 0.5) * 10 +
          math.sin((life * 3 + _seed(i)) * math.pi) * 3;
      final y = base.dy - 12 - life * 36;
      canvas.drawCircle(
        Offset(x, y),
        0.9 * (1 - life) + 0.3,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFD642),
            const Color(0xFFE78A0C),
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  static double _seed(int seed) {
    final x = math.sin(seed * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }
}
