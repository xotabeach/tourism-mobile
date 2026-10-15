import 'dart:math' as math;
import 'dart:ui';

part 'bean_art_data.dart';

/// One character as the designer drew it (FRONTEND-79): every part as an
/// SVG path in the drawing's own units, so it can be moved on its own.
class BeanArtData {
  const BeanArtData({
    required this.size,
    required this.ground,
    required this.shadowColor,
    required this.limbColor,
    required this.bodyTop,
    required this.bodyBottom,
    required this.highlightColor,
    required this.shadow,
    required this.armLeft,
    required this.armRight,
    required this.legLeft,
    required this.legRight,
    required this.body,
    required this.highlight,
    required this.mouth,
    required this.eyeLeft,
    required this.eyeRight,
    required this.shineLeft,
    required this.shineRight,
  });

  /// The drawing's view box. All four share one scale: the blue one is
  /// 404 tall with its shadow, the others taller or shorter by as much as
  /// they are on the sketch.
  final Size size;

  /// The middle of the shadow: where the character stands.
  final Offset ground;
  final Color shadowColor;
  final Color limbColor;
  final Color bodyTop;
  final Color bodyBottom;
  final Color highlightColor;
  final String shadow;
  final String armLeft;
  final String armRight;
  final String legLeft;
  final String legRight;
  final String body;
  final String highlight;
  final String mouth;
  final String eyeLeft;
  final String eyeRight;
  final String shineLeft;
  final String shineRight;
}

/// The blue character's height in the drawing's units.
const double beanArtBlueHeight = 404;

/// The parts of [data] as paths, with what the code needs to dress and
/// animate them: the body's width at any height, the eyes, the mouth and
/// where the arms turn.
class BeanArt {
  BeanArt._(this.data)
    : shadow = parseSvgPath(data.shadow),
      armLeft = parseSvgPath(data.armLeft),
      armRight = parseSvgPath(data.armRight),
      legLeft = parseSvgPath(data.legLeft),
      legRight = parseSvgPath(data.legRight),
      body = parseSvgPath(data.body),
      highlight = parseSvgPath(data.highlight),
      mouth = parseSvgPath(data.mouth),
      eyeLeft = parseSvgPath(data.eyeLeft),
      eyeRight = parseSvgPath(data.eyeRight),
      shineLeft = parseSvgPath(data.shineLeft),
      shineRight = parseSvgPath(data.shineRight) {
    // The body path leaves a notch where the highlight sits.
    solidBody = Path.combine(PathOperation.union, body, highlight);
    final solid = solidBody;
    bodyBounds = solid.getBounds();
    final rows = <double>[];
    final cx = bodyBounds.center.dx;
    for (var i = 0; i <= _rows; i++) {
      final y = bodyBounds.top + bodyBounds.height * i / _rows;
      double edge(double towards) {
        if (!solid.contains(Offset(cx, y))) return cx;
        var inside = cx;
        var outside = towards;
        for (var k = 0; k < 14; k++) {
          final mid = (inside + outside) / 2;
          if (solid.contains(Offset(mid, y))) {
            inside = mid;
          } else {
            outside = mid;
          }
        }
        return inside;
      }

      rows.add((edge(bodyBounds.right + 1) - edge(bodyBounds.left - 1)) / 2);
    }
    _halfWidths = rows;
    final l = armLeft.getBounds();
    final r = armRight.getBounds();
    shoulderLeft = Offset(l.right - l.width * 0.12, l.top + l.height * 0.12);
    shoulderRight = Offset(r.left + r.width * 0.12, r.top + r.height * 0.12);
    handLeft = Offset(l.left + l.width * 0.15, l.bottom - l.height * 0.2);
    handRight = Offset(r.right - r.width * 0.15, r.bottom - r.height * 0.2);
  }

  static const _rows = 96;
  static final _cache = <BeanArtData, BeanArt>{};

  static BeanArt of(BeanArtData data) =>
      _cache.putIfAbsent(data, () => BeanArt._(data));

  final BeanArtData data;
  final Path shadow;
  final Path armLeft;
  final Path armRight;
  final Path legLeft;
  final Path legRight;
  final Path body;
  final Path highlight;
  final Path mouth;
  final Path eyeLeft;
  final Path eyeRight;
  final Path shineLeft;
  final Path shineRight;

  /// The body with its highlight notch filled.
  late final Path solidBody;
  late final Rect bodyBounds;
  late final List<double> _halfWidths;
  late final Offset shoulderLeft;
  late final Offset shoulderRight;
  late final Offset handLeft;
  late final Offset handRight;

  /// Half the body's width at [y], in the drawing's units.
  double halfWidthAt(double y) {
    final t = (y - bodyBounds.top) / bodyBounds.height * _rows;
    if (t <= 0 || t >= _rows) return 0;
    final i = t.floor();
    final f = t - i;
    return _halfWidths[i] * (1 - f) + _halfWidths[math.min(i + 1, _rows)] * f;
  }
}

/// The art of each build.
BeanArtData beanArtData(String kindSlug) => switch (kindSlug) {
  'tall' => _tall,
  'small' => _small,
  'round' => _round,
  _ => _pin,
};

/// Parses the absolute M, L, H, V, C and Z commands the design tool exports.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(
    r'[MLHVCZmlhvcz]|-?\d*\.?\d+(?:e-?\d+)?',
  ).allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var command = 'M';
  var x = 0.0;
  var y = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final token = tokens[i];
    if (RegExp('[MLHVCZmlhvcz]').hasMatch(token)) {
      command = token.toUpperCase();
      i++;
      if (command == 'Z') {
        path.close();
        continue;
      }
    }
    switch (command) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
        // Numbers after a move are lines.
        command = 'L';
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      default:
        i++;
    }
  }
  return path;
}
