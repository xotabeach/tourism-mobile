import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// Someone sitting at the fire.
class CampMember {
  const CampMember({
    required this.userId,
    required this.name,
    this.ready = false,
    this.organizer = false,
    this.waiting = false,
  });

  final String userId;
  final String name;

  /// «Готов»: holds a marshmallow over the fire.
  final bool ready;
  final bool organizer;

  /// Invited or asking in: not at the fire yet, drawn faded at the edge.
  final bool waiting;
}

/// The gathering screen as a camp (spec 11b D17): the group sits around a
/// fire, «готов» puts a marshmallow over it, and the organizer's start
/// sends everyone hopping off onto the trail.
class CampfireScene extends StatefulWidget {
  const CampfireScene({
    required this.members,
    this.departing = false,
    this.onDeparted,
    this.height = 300,
    super.key,
  });

  final List<CampMember> members;

  /// Plays the walk-off once; [onDeparted] fires when the last bean is gone.
  final bool departing;
  final VoidCallback? onDeparted;
  final double height;

  @override
  State<CampfireScene> createState() => _CampfireSceneState();
}

class _CampfireSceneState extends State<CampfireScene>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  late final AnimationController _depart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
  void didUpdateWidget(CampfireScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.departing && !oldWidget.departing) {
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.onDeparted?.call();
      } else {
        unawaited(
          _depart
              .forward(from: 0)
              .whenComplete(() => widget.onDeparted?.call()),
        );
      }
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _depart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.members.where((m) => m.ready && !m.waiting).length;
    final seated = widget.members.where((m) => !m.waiting).length;
    return Semantics(
      label: 'Лагерь группы: у костра $seated, готовы $ready',
      excludeSemantics: true,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _depart]),
            builder: (context, _) => CustomPaint(
              painter: _CampPainter(
                members: widget.members,
                t: _idle.value,
                depart: _depart.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampPainter extends CustomPainter {
  _CampPainter({required this.members, required this.t, required this.depart});

  final List<CampMember> members;
  final double t;
  final double depart;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));

    canvas.drawRect(rect, Paint()..color = FlatPalette.night);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.35, w, h * 0.3),
      Paint()..color = FlatPalette.nightLow,
    );
    // Stars twinkle by size, never by colour.
    for (var i = 0; i < 26; i++) {
      final x = seeded(i) * w;
      final y = seeded(i + 100) * h * 0.42;
      final pulse = 0.6 + 0.4 * math.sin((t * 2 + seeded(i + 7)) * math.pi * 2);
      canvas.drawCircle(
        Offset(x, y),
        (1 + seeded(i + 50) * 1.6) * pulse,
        Paint()..color = FlatPalette.star,
      );
    }
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.16),
      h * 0.07,
      Paint()..color = FlatPalette.moon,
    );
    canvas.drawCircle(
      Offset(w * 0.82 + h * 0.03, h * 0.16 - h * 0.015),
      h * 0.07,
      Paint()..color = FlatPalette.night,
    );

    final far = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.2, h * 0.36, w * 0.42, h * 0.55)
      ..quadraticBezierTo(w * 0.62, h * 0.32, w * 0.86, h * 0.52)
      ..quadraticBezierTo(w * 0.95, h * 0.46, w, h * 0.5)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = FlatPalette.hillFar);
    final near = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.35, h * 0.56, w * 0.7, h * 0.64)
      ..quadraticBezierTo(w * 0.88, h * 0.68, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = FlatPalette.hillNear);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.74, w, h * 0.26),
      Paint()..color = FlatPalette.ground,
    );

    // The trail the group leaves by, to the right.
    final trail = Path()
      ..moveTo(w * 0.5, h * 0.86)
      ..quadraticBezierTo(w * 0.8, h * 0.8, w * 1.05, h * 0.78);
    canvas.drawPath(
      trail,
      Paint()
        ..color = FlatPalette.groundDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.05
        ..strokeCap = StrokeCap.round,
    );

    final fire = Offset(w / 2, h * 0.84);
    _paintFire(canvas, fire, h);

    final seated = [
      for (final m in members)
        if (!m.waiting) m,
    ];
    final waiting = [
      for (final m in members)
        if (m.waiting) m,
    ];
    final beanHeight = h * 0.2;

    // Half the group on each side of the fire, the further ones a little
    // higher up the slope, as if sitting round it.
    final placed = <(Offset, CampMember, int)>[];
    for (var i = 0; i < seated.length; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final rank = i ~/ 2;
      final feet = Offset(
        fire.dx + side * (h * 0.24 + rank * beanHeight * 0.82),
        fire.dy + h * 0.03 - rank * h * 0.045,
      );
      placed.add((feet, seated[i], i));
    }
    placed.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));

    for (final (feet, member, index) in placed) {
      final offsetT = (t + index * 0.17) % 1;
      final hop = depart > 0
          ? (math.sin(depart * math.pi * 10 + index).abs() * 0.18)
          : (math.sin(offsetT * math.pi * 2) * 0.025).abs();
      // Walking off: each bean leaves a little after the one before.
      final leave = depart <= 0
          ? 0.0
          : ((depart * 1.4 - index * 0.08).clamp(0.0, 1.0));
      final position = Offset.lerp(
        feet,
        Offset(w + beanHeight, h * 0.78),
        Curves.easeIn.transform(leave),
      )!;
      final blink = ((t * 6 + index * 0.37) % 1) < 0.04;
      paintBean(
        canvas,
        position,
        beanHeight,
        FlatPalette.beanFor(member.userId),
        BeanPose(
          bob: hop,
          blink: blink,
          lookX: depart > 0 ? 1 : (fire.dx - feet.dx).sign * 0.8,
          ready: member.ready && depart <= 0,
          organizer: member.organizer,
          stickToRight: feet.dx < fire.dx,
        ),
      );
      if (depart <= 0) {
        paintLabel(
          canvas,
          position.translate(0, 4),
          member.name,
          size: math.max(10, h * 0.04),
          maxWidth: beanHeight * 1.6,
        );
      }
    }

    // Those still on their way are small and faded on the far hill.
    for (var i = 0; i < waiting.length; i++) {
      final feet = Offset(
        w * 0.12 + i * beanHeight * 0.4,
        h * 0.5 + i * h * 0.01,
      );
      paintBean(
        canvas,
        feet,
        beanHeight * 0.42,
        FlatPalette.beanFor(waiting[i].userId),
        BeanPose(dim: true, lookX: 1, blink: ((t * 5 + i) % 1) < 0.05),
      );
    }
    canvas.restore();
  }

  void _paintFire(Canvas canvas, Offset base, double h) {
    // Firelight on the grass: a flat lighter patch that breathes.
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, h * 0.02),
        width: h * 0.62 + math.sin(t * math.pi * 12) * h * 0.02,
        height: h * 0.16,
      ),
      Paint()..color = FlatPalette.firelight,
    );
    final logW = h * 0.2;
    for (final tilt in const [-0.35, 0.35]) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(tilt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: logW, height: h * 0.045),
          Radius.circular(h * 0.02),
        ),
        Paint()..color = tilt < 0 ? FlatPalette.log : FlatPalette.logDark,
      );
      canvas.restore();
    }
    // Three flames, each flickering on its own beat.
    final layers = [
      (FlatPalette.flameOuter, 1.0, 0.0),
      (FlatPalette.flameMid, 0.7, 0.33),
      (FlatPalette.flameCore, 0.42, 0.66),
    ];
    for (final (color, scale, phase) in layers) {
      final flick = 1 + 0.12 * math.sin((t * 10 + phase) * math.pi * 2);
      final tall = h * 0.2 * scale * flick;
      final wide = h * 0.13 * scale;
      final sway = math.sin((t * 7 + phase) * math.pi * 2) * wide * 0.15;
      final flame = Path()
        ..moveTo(base.dx - wide / 2, base.dy - h * 0.01)
        ..quadraticBezierTo(
          base.dx - wide / 2,
          base.dy - tall * 0.55,
          base.dx + sway,
          base.dy - tall,
        )
        ..quadraticBezierTo(
          base.dx + wide / 2,
          base.dy - tall * 0.55,
          base.dx + wide / 2,
          base.dy - h * 0.01,
        )
        ..close();
      canvas.drawPath(flame, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _CampPainter old) =>
      old.t != t || old.depart != depart || old.members != members;
}
