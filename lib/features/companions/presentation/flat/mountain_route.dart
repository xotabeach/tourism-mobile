import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_head.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// Someone on the mountain: which character, how far up the trail.
class MountainWalker {
  const MountainWalker({required this.kind, required this.at});

  final BeanKind kind;

  /// Stops reached, as a stop index from 0; a fraction is between stops.
  final double at;
}

/// The group on its way (FRONTEND-89): the designer's mountain with a
/// dashed trail, the route's stops numbered on it from the foot to the
/// peak, and everyone's head where they are.
///
/// The trail is the designer's, traced; any number of stops is spread on
/// it so that five land exactly where the mockup has them.
class MountainRoute extends StatelessWidget {
  const MountainRoute({required this.stops, required this.walkers, super.key});

  final int stops;
  final List<MountainWalker> walkers;

  /// The picture's own proportions.
  static const aspect = 1062 / 708;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspect,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/companions/mountain.jpg',
              fit: BoxFit.cover,
            ),
            CustomPaint(painter: _TrailPainter(stops, walkers)),
          ],
        ),
      ),
    ),
  );
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.stops, this.walkers);

  final int stops;
  final List<MountainWalker> walkers;

  static const _ring = Color(0xFF1D71CB);
  static const _dash = Color(0xFF519EF0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final pts = [
      for (final p in mountainTrail) Offset(p.dx * w, p.dy * size.height),
    ];
    final lengths = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      lengths.add(lengths.last + (pts[i] - pts[i - 1]).distance);
    }
    final total = lengths.last;
    double fractionOfIndex(int i) => lengths[i] / total;
    final designer = [for (final i in mountainTrailStops) fractionOfIndex(i)];

    /// Where stop [k] of [n] sits along the trail (0 the foot, 1 the peak).
    double stopFraction(double k, int n) {
      if (n <= 1) return 0;
      final t = (k / (n - 1)).clamp(0.0, 1.0) * (designer.length - 1);
      final i = t.floor().clamp(0, designer.length - 2);
      final f = t - i;
      return designer[i] + (designer[i + 1] - designer[i]) * f;
    }

    Offset pointAt(double fraction) {
      final target = fraction.clamp(0.0, 1.0) * total;
      for (var i = 1; i < pts.length; i++) {
        if (lengths[i] >= target) {
          final f = (target - lengths[i - 1]) / (lengths[i] - lengths[i - 1]);
          return Offset.lerp(pts[i - 1], pts[i], f.isFinite ? f : 0)!;
        }
      }
      return pts.last;
    }

    // The dashed trail, a smooth line through the traced points.
    final trail = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      trail.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final dashPaint = Paint()
      ..color = _dash
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.0062
      ..strokeCap = StrokeCap.round;
    final dash = w * 0.0155;
    final gap = w * 0.0115;
    for (final metric in trail.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          dashPaint,
        );
      }
    }

    // The stops: a white disc in a blue ring, the number in the middle.
    final outer = w * 0.0278;
    final inner = w * 0.0194;
    final count = math.max(stops, 1);
    for (var k = 0; k < count; k++) {
      final c = pointAt(stopFraction(k.toDouble(), count));
      canvas.drawCircle(c, outer, Paint()..color = _ring);
      canvas.drawCircle(c, inner, Paint()..color = Colors.white);
      final label = TextPainter(
        text: TextSpan(
          text: '${k + 1}',
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: inner * (k + 1 >= 10 ? 1.05 : 1.3),
            fontWeight: FontWeight.w700,
            color: _ring,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c - Offset(label.width / 2, label.height / 2));
    }

    // Heads: grouped round the same spot, as on the mockup at the start.
    const slots = [
      Offset(-0.048, -0.026),
      Offset(0, -0.052),
      Offset(0.052, -0.026),
      Offset(0.052, 0.024),
      Offset(-0.048, 0.024),
      Offset(0, 0.05),
      Offset(-0.096, 0),
      Offset(0.1, 0),
    ];
    final taken = <String, int>{};
    final head = w * 0.04;
    for (final walker in walkers) {
      final spot = stopFraction(walker.at, count);
      final key = spot.toStringAsFixed(3);
      final slot = taken.update(key, (n) => n + 1, ifAbsent: () => 0);
      final at = pointAt(spot) + slots[slot % slots.length] * w;
      paintBeanHead(canvas, at, head, walker.kind, ring: head * 0.06);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.stops != stops || old.walkers != walkers;
}

/// The designer's trail up the mountain (FRONTEND-89), traced from the
/// mockup: points from the first stop to the peak, as shares of the
/// picture's width and height.
const mountainTrail = <Offset>[
  Offset(0.7, 0.9017),
  Offset(0.6569, 0.9062),
  Offset(0.6376, 0.9073),
  Offset(0.6163, 0.907),
  Offset(0.5953, 0.9052),
  Offset(0.5741, 0.9015),
  Offset(0.5531, 0.8947),
  Offset(0.5325, 0.8858),
  Offset(0.5123, 0.8754),
  Offset(0.4925, 0.8643),
  Offset(0.4512, 0.8385),
  Offset(0.491, 0.7967),
  Offset(0.5079, 0.7709),
  Offset(0.5209, 0.7414),
  Offset(0.5264, 0.7073),
  Offset(0.5169, 0.6822),
  Offset(0.4969, 0.6919),
  Offset(0.479, 0.7095),
  Offset(0.4613, 0.7283),
  Offset(0.4437, 0.7466),
  Offset(0.4253, 0.7635),
  Offset(0.4059, 0.7767),
  Offset(0.3847, 0.7828),
  Offset(0.3642, 0.7733),
  Offset(0.3474, 0.7482),
  Offset(0.3347, 0.7174),
  Offset(0.3169, 0.6501),
  Offset(0.3184, 0.5824),
  Offset(0.3244, 0.5509),
  Offset(0.3379, 0.525),
  Offset(0.359, 0.523),
  Offset(0.3751, 0.5465),
  Offset(0.3878, 0.5745),
  Offset(0.4007, 0.6027),
  Offset(0.4169, 0.6255),
  Offset(0.4382, 0.627),
  Offset(0.4542, 0.6065),
  Offset(0.4644, 0.5814),
  Offset(0.479, 0.5202),
  Offset(0.438, 0.4985),
  Offset(0.4214, 0.4852),
  Offset(0.4057, 0.4664),
  Offset(0.3952, 0.4396),
  Offset(0.3953, 0.4025),
  Offset(0.412, 0.3317),
];

/// Where the mockup's five stops fall on [mountainTrail], by point index.
const mountainTrailStops = <int>[0, 10, 26, 38, 44];
