import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/camp_art.dart';
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
    this.shade = false,
    this.labelsAbove = false,
    super.key,
  });

  /// Names over the heads, as on the designer's lobby (FRONTEND-88).
  final bool labelsAbove;

  /// A soft dark patch behind each person, so they stand out from the
  /// busy camp (owner's idea, FRONTEND-86; to be decided).
  final bool shade;

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
                shade: widget.shade,
                labelsAbove: widget.labelsAbove,
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
    this.shade = false,
    this.labelsAbove = false,
  });

  final bool closeUp;
  final bool shade;
  final bool labelsAbove;

  final List<CampMember> members;
  final double t;
  final double depart;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));

    // The designer's camp (FRONTEND-86) covers the box, cropped round the
    // fire; everything below is drawn in its 362×241 frame.
    const frame = CampArt.frame;
    final s = math.max(size.width / frame.width, size.height / frame.height);
    final fireX = CampArt.fireBase.dx * s;
    final dx = (size.width / 2 - fireX).clamp(
      size.width - frame.width * s,
      0.0,
    );
    final dy = size.height - frame.height * s;
    canvas.translate(dx, dy);
    canvas.scale(s);
    final still = t.isNaN;
    final time = still ? 0.0 : t;
    CampArt.paintBack(canvas, time, still: still);
    final w = frame.width;
    final fire = CampArt.fireBase;

    final seated = [
      for (final m in members)
        if (!m.waiting) m,
    ];
    final waiting = [
      for (final m in members)
        if (m.waiting) m,
    ];
    // Fewer people stand larger: four fill the clearing, eight still fit
    // (owner, 2026-10-16: four looked lost at the size of eight).
    final beanHeight = closeUp
        ? 74.0
        : seated.length <= 4
        ? 52.0
        : seated.length <= 6
        ? 44.0
        : 36.0;
    final spread = beanHeight / 34;

    // Half the group on each side of the fire, the further ones a little
    // higher up the slope, as if sitting round it.
    final placed = <(Offset, CampMember, int)>[];
    for (var i = 0; i < seated.length; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final rank = i ~/ 2;
      // In front of the tents, on the grass round the fire.
      final feet = closeUp
          ? Offset(fire.dx - 58, fire.dy + 30)
          : Offset(
              fire.dx + side * (26 + rank * 25) * spread,
              // Every other pair a step back, so the group closes round
              // the fire instead of standing in a line.
              fire.dy + (rank.isOdd ? 2 : 10) * spread,
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
      final end = Offset(w + beanHeight, fire.dy + 20);
      final control = Offset(fire.dx, fire.dy + 40);
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
      if (shade) {
        canvas.drawOval(
          Rect.fromCenter(
            center: position.translate(0, -beanHeight * 0.5),
            width: beanHeight * 1.5,
            height: beanHeight * 1.6,
          ),
          Paint()
            ..color = const Color(0x8C000000)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, beanHeight * 0.22),
        );
      }
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
        final kindHeight =
            beanHeight * member.look.kind.art.data.size.height / 404;
        paintLabel(
          canvas,
          labelsAbove
              ? position.translate(0, -kindHeight - 6 / s - 4)
              : position.translate(0, 4),
          member.name,
          size: math.max(10 / s, 7),
          maxWidth: beanHeight * 1.6,
        );
      }
    }

    // Those still on their way are small and faded on the far hill.
    for (var i = 0; i < waiting.length; i++) {
      // Coming round the yellow tent.
      final feet = Offset(fire.dx - 112 + i * 12, fire.dy - 6 - i * 1.5);
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
    CampArt.paintFront(canvas, time, still: still);
    canvas.restore();
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
