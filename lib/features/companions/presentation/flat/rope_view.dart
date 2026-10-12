import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// «Связка» (spec 11b D17): the route as a rope with a knot at every stop,
/// the group as beans on it. Each bean stands at its last marked stop; the
/// rope is green where everyone who started has passed and pale green up
/// to whoever leads, so it shows how far the group has stretched.
class RopeView extends StatefulWidget {
  const RopeView({required this.progress, this.height = 170, super.key});

  final CompanionProgress progress;
  final double height;

  @override
  State<RopeView> createState() => _RopeViewState();
}

class _RopeViewState extends State<RopeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      unawaited(_idle.repeat());
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.progress.stops.length;
    // About 78 pt a stop; a long route scrolls sideways.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, stops * 78.0 + 90);
        final scene = SizedBox(
          width: width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _idle,
            builder: (context, _) => CustomPaint(
              painter: _RopePainter(widget.progress, _idle.value),
            ),
          ),
        );
        return Semantics(
          label: _describe(widget.progress),
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ColoredBox(
              color: FlatPalette.paper,
              child: width > constraints.maxWidth
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: scene,
                    )
                  : scene,
            ),
          ),
        );
      },
    );
  }

  static String _describe(CompanionProgress progress) => [
    for (final member in progress.members)
      '${member.displayName}: ${member.status.label}, '
          'точка ${member.lastPosition} из ${progress.stops.length}',
  ].join('; ');
}

class _RopePainter extends CustomPainter {
  _RopePainter(this.progress, this.t);

  final CompanionProgress progress;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final stops = progress.stops;
    if (stops.isEmpty) return;
    final h = size.height;
    // Room on the left for those who have not started yet.
    const start = 30.0;
    const left = 84.0;
    final right = size.width - 30;
    final y = h * 0.66;
    final step = stops.length == 1 ? 0.0 : (right - left) / (stops.length - 1);
    Offset knot(int index) => Offset(left + step * index, y);

    // The rope sags a little between knots.
    Path ropeBetween(double from, double to) {
      final path = Path()..moveTo(from, y);
      final segments = <double>[];
      for (var i = 0; i < stops.length; i++) {
        final x = knot(i).dx;
        if (x > from && x < to) segments.add(x);
      }
      segments.add(to);
      var x0 = from;
      for (final x1 in segments) {
        path.quadraticBezierTo((x0 + x1) / 2, y + 7, x1, y);
        x0 = x1;
      }
      return path;
    }

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(ropeBetween(left, right), stroke(FlatPalette.rope, 7));

    final started = [
      for (final m in progress.members)
        if (m.status != CompanionRunStatus.notStarted) m,
    ];
    if (started.isNotEmpty) {
      final rear = started.map((m) => m.lastPosition).reduce(math.min);
      final lead = started.map((m) => m.lastPosition).reduce(math.max);
      double xOf(int position) => position <= 0 ? left : knot(position - 1).dx;
      if (lead > 0) {
        canvas.drawPath(
          ropeBetween(left, xOf(lead)),
          stroke(FlatPalette.trail.withValues(alpha: 0.35), 9),
        );
      }
      if (rear > 0) {
        canvas.drawPath(
          ropeBetween(left, xOf(rear)),
          stroke(FlatPalette.trail, 9),
        );
      }
    }

    // Knots: a number in a flat disc; the first to arrive gets a crown in
    // their own colour.
    for (var i = 0; i < stops.length; i++) {
      final center = knot(i);
      canvas.drawCircle(center, 13, Paint()..color = FlatPalette.ropeDark);
      canvas.drawCircle(center, 10, Paint()..color = FlatPalette.white);
      final number = TextPainter(
        text: TextSpan(
          text: '${stops[i].position}',
          style: const TextStyle(
            fontFamily: 'Rubik',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: FlatPalette.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(
        canvas,
        center.translate(-number.width / 2, -number.height / 2),
      );
      final first = stops[i].firstUserId;
      if (first != null && !progress.leaderboardHidden) {
        _crown(canvas, center.translate(0, 22), FlatPalette.beanFor(first));
      }
    }

    // Beans stand on their last stop; several at one stop line up behind
    // each other.
    final byStop = <int, List<CompanionMemberProgress>>{};
    for (final member in progress.members) {
      byStop.putIfAbsent(member.lastPosition, () => []).add(member);
    }
    final beanHeight = h * 0.34;
    var order = 0;
    for (final entry in byStop.entries) {
      final base = entry.key <= 0 ? Offset(start + 8, y) : knot(entry.key - 1);
      for (var k = 0; k < entry.value.length; k++) {
        final member = entry.value[k];
        final spread = (k - (entry.value.length - 1) / 2) * beanHeight * 0.62;
        final feet = base.translate(spread, k.isOdd ? -9 : -6);
        final walking = member.status == CompanionRunStatus.walking;
        final hop = walking
            ? (math.sin((t * 2 + order * 0.23) * math.pi * 2) * 0.05).abs()
            : 0.0;
        paintBean(
          canvas,
          feet,
          beanHeight,
          FlatPalette.beanFor(member.userId),
          BeanPose(
            look: BeanLook.forUser(member.userId, hat: member.beanHat),
            breath: math.sin((t * 2 + order * 0.31) * math.pi * 2),
            step: walking ? math.sin((t * 4 + order * 0.2) * math.pi * 2) : 0,
            flutter: t * 4,
            bob: hop,
            blink: ((t * 3 + order * 0.31) % 1) < 0.05,
            lookX: 1,
            organizer: member.isOrganizer,
            dim:
                member.status == CompanionRunStatus.notStarted ||
                member.status == CompanionRunStatus.quit ||
                member.status == CompanionRunStatus.notFinished,
            happy: member.status == CompanionRunStatus.finished,
          ),
        );
        if (member.status == CompanionRunStatus.paused) {
          _bubble(
            canvas,
            feet.translate(beanHeight * 0.35, -beanHeight * 1.05),
          );
        }
        order++;
      }
    }
  }

  void _crown(Canvas canvas, Offset center, Color color) {
    final crown = Path()
      ..moveTo(center.dx - 8, center.dy + 4)
      ..lineTo(center.dx - 8, center.dy - 3)
      ..lineTo(center.dx - 4, center.dy + 1)
      ..lineTo(center.dx, center.dy - 5)
      ..lineTo(center.dx + 4, center.dy + 1)
      ..lineTo(center.dx + 8, center.dy - 3)
      ..lineTo(center.dx + 8, center.dy + 4)
      ..close();
    canvas.drawPath(crown, Paint()..color = color);
  }

  /// «На паузе»: a little bubble with two bars.
  void _bubble(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 9, Paint()..color = FlatPalette.white);
    for (final dx in const [-2.5, 2.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(dx, 0),
            width: 2.6,
            height: 8,
          ),
          const Radius.circular(1.3),
        ),
        Paint()..color = FlatPalette.ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) =>
      old.t != t || old.progress != progress;
}
