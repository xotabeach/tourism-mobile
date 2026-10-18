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
    this.hat,
    this.kind,
    this.outfit,
  });

  final String userId;

  /// The chosen hat's slug; null draws the account's own.
  final String? hat;

  /// The chosen character and clothes (FRONTEND-79).
  final String? kind;
  final String? outfit;

  BeanLook get look =>
      BeanLook.forUser(userId, hat: hat, kind: kind, outfit: outfit);
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
    this.closeUp = false,
    super.key,
  });

  /// One person, drawn large beside the fire: «Мой персонаж».
  final bool closeUp;

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
                closeUp: widget.closeUp,
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
  _CampPainter({
    required this.members,
    required this.t,
    required this.depart,
    this.closeUp = false,
  });

  final bool closeUp;

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

    // Once a cycle a star falls across the sky.
    final fall = (t - 0.3) / 0.08;
    if (fall > 0 && fall < 1) {
      final from = Offset(w * (0.15 + fall * 0.35), h * (0.06 + fall * 0.16));
      canvas.drawLine(
        from,
        from.translate(-w * 0.07, -h * 0.03),
        Paint()
          ..color = FlatPalette.star.withValues(alpha: 1 - fall)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

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

    // Fireflies blink in the grass.
    for (var i = 0; i < 7; i++) {
      final phase = (t * 3 + seeded(i + 300)) % 1;
      final glow = math.max(0.0, math.sin(phase * math.pi * 2));
      if (glow <= 0) continue;
      final x =
          w * (0.05 + seeded(i + 310) * 0.9) +
          math.sin((t * 2 + seeded(i)) * math.pi * 2) * w * 0.02;
      final y =
          h * (0.78 + seeded(i + 320) * 0.18) +
          math.cos((t * 3 + seeded(i)) * math.pi * 2) * h * 0.015;
      canvas.drawCircle(
        Offset(x, y),
        2.2,
        Paint()..color = FlatPalette.flameCore.withValues(alpha: glow),
      );
    }

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
    final beanHeight = closeUp ? h * 0.42 : h * 0.2;

    // Half the group on each side of the fire, the further ones a little
    // higher up the slope, as if sitting round it.
    final placed = <(Offset, CampMember, int)>[];
    for (var i = 0; i < seated.length; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final rank = i ~/ 2;
      final feet = closeUp
          ? Offset(fire.dx - h * 0.42, fire.dy + h * 0.1)
          : Offset(
              fire.dx + side * (h * 0.24 + rank * beanHeight * 0.82),
              fire.dy + h * 0.03 - rank * h * 0.045,
            );
      placed.add((feet, seated[i], i));
    }
    placed.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));

    for (final (feet, member, index) in placed) {
      final phase = seeded(index + 40);
      final breath = math.sin((t * 3 + phase) * math.pi * 2);
      final leaving = depart > 0;
      // Walking off: each bean leaves a little after the one before.
      final leave = leaving
          ? ((depart * 1.4 - index * 0.08).clamp(0.0, 1.0))
          : 0.0;
      // Round the front of the fire, never through it, then up the trail.
      final k = Curves.easeIn.transform(leave);
      final end = Offset(w + beanHeight, h * 0.8);
      final control = Offset(fire.dx, h * 1.02);
      final position = Offset(
        (1 - k) * (1 - k) * feet.dx +
            2 * (1 - k) * k * control.dx +
            k * k * end.dx,
        (1 - k) * (1 - k) * feet.dy +
            2 * (1 - k) * k * control.dy +
            k * k * end.dy,
      );
      final towardFire = (fire.dx - feet.dx).sign * 0.8;
      // Now and then a bean looks at you, or round at the night.
      final glance = (t * 2 + phase) % 1;
      // Eyes glide between targets instead of jumping.
      final atYou = _window(glance, 0.05, 0.17);
      final away = _window(glance, 0.55, 0.63);
      final look = leaving
          ? 1.0
          : towardFire * (1 - atYou - away) - towardFire * away;
      // Those not ready yet wave at the others from time to time.
      final waveBeat = (t * 2 + phase * 0.7) % 1;
      final wave = leaving
          ? 0.7
          : !member.ready && waveBeat < 0.2
          ? 0.65 + 0.35 * math.sin(waveBeat / 0.2 * math.pi * 6)
          : 0.0;
      paintBean(
        canvas,
        position,
        beanHeight,
        FlatPalette.beanFor(member.userId),
        BeanPose(
          bob: leaving
              ? (math.sin(depart * math.pi * 14 + index).abs() * 0.08)
              : 0,
          breath: leaving ? 0 : breath,
          step: leaving ? math.sin(depart * math.pi * 14 + index) : 0,
          blink: ((t * 6 + index * 0.37) % 1) < 0.04,
          lookX: look,
          ready: member.ready && !leaving,
          toast: (t * 2 + phase) % 1,
          wave: wave,
          mouthOpen: leaving && leave < 0.6,
          organizer: member.organizer,
          flutter: t * 6,
          stickToRight: feet.dx < fire.dx,
          look: member.look,
        ),
      );
      if (!leaving) {
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
        BeanPose(
          dim: true,
          lookX: 1,
          blink: ((t * 5 + i) % 1) < 0.05,
          // On their way: waving to those at the fire.
          wave: 0.6 + 0.4 * math.sin((t * 6 + i * 0.3) * math.pi * 2),
          step: math.sin((t * 6 + i) * math.pi * 2),
          look: waiting[i].look,
        ),
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
    // Smoke rises in soft flat puffs, drifting with the night air.
    for (var i = 0; i < 4; i++) {
      final rise = (t * 2 + i / 4) % 1;
      canvas.drawCircle(
        base.translate(
          rise * h * 0.12 + math.sin(rise * math.pi * 2) * h * 0.02,
          -h * 0.2 - rise * h * 0.5,
        ),
        h * (0.03 + rise * 0.06),
        Paint()..color = Colors.white.withValues(alpha: 0.12 * (1 - rise)),
      );
    }
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
      // The cut ends show their rings.
      for (final end in const [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset(end * logW / 2, 0),
          h * 0.024,
          Paint()..color = const Color(0xFFE3B47A),
        );
        canvas.drawCircle(
          Offset(end * logW / 2, 0),
          h * 0.011,
          Paint()..color = FlatPalette.log,
        );
      }
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
    // Two small tongues lick up at the sides.
    for (final side in const [-1.0, 1.0]) {
      final lick = 0.5 + 0.5 * math.sin((t * 9 + side) * math.pi * 2);
      final tongueBase = base.translate(side * h * 0.07, -h * 0.01);
      final tall = h * (0.05 + 0.06 * lick);
      canvas.drawPath(
        Path()
          ..moveTo(tongueBase.dx - h * 0.025, tongueBase.dy)
          ..quadraticBezierTo(
            tongueBase.dx - h * 0.02,
            tongueBase.dy - tall * 0.6,
            tongueBase.dx + side * h * 0.02,
            tongueBase.dy - tall,
          )
          ..quadraticBezierTo(
            tongueBase.dx + h * 0.02,
            tongueBase.dy - tall * 0.5,
            tongueBase.dx + h * 0.025,
            tongueBase.dy,
          )
          ..close(),
        Paint()..color = FlatPalette.flameMid,
      );
    }
    // Sparks fly up, wobble and go out.
    for (var i = 0; i < 14; i++) {
      final life = (t * 2 + seeded(i + 200)) % 1;
      final x =
          base.dx +
          (seeded(i + 210) - 0.5) * h * 0.16 +
          math.sin((life * 3 + seeded(i)) * math.pi) * h * 0.04;
      final y = base.dy - h * 0.12 - life * h * 0.42;
      canvas.drawCircle(
        Offset(x, y),
        h * 0.011 * (1 - life) + 0.6,
        Paint()
          ..color = Color.lerp(
            FlatPalette.flameCore,
            FlatPalette.flameOuter,
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CampPainter old) =>
      old.t != t || old.depart != depart || old.members != members;
}

/// 1 inside [from]..[to] on the 0..1 loop, 0 outside, with soft edges.
double _window(double x, double from, double to) {
  const ramp = 0.03;
  double smooth(double a, double b, double v) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  return smooth(from - ramp, from, x) * (1 - smooth(to, to + ramp, x));
}
