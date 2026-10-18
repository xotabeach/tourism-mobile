import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/companions/presentation/flat/bean_art.dart';
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
    this.radius = 24,
    super.key,
  });

  /// The corners: 10 on the designer's lobby (FRONTEND-88).
  final double radius;

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
                radius: widget.radius,
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
    this.radius = 24,
  });

  final bool closeUp;
  final bool shade;
  final bool labelsAbove;
  final double radius;

  final List<CampMember> members;
  final double t;
  final double depart;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

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
    // Fewer people stand larger: two or four as on the designer's lobby,
    // eight still fit (owner, 2026-10-16: four looked lost at the size of
    // eight).
    final beanHeight = closeUp
        ? 74.0
        : seated.length <= 4
        ? 50.0
        : seated.length <= 6
        ? 43.0
        : 37.0;

    // Each person on their own patch of grass round the fire, the first two
    // where the designer put them: before the yellow tent and right of the
    // fire. The rest fill in round the front, clear of the tents, the log
    // and the bushes (owner, 2026-10-18: they stood in a tight line).
    final placed = <(Offset, CampMember, int)>[];
    for (var i = 0; i < seated.length; i++) {
      final feet = closeUp
          ? Offset(fire.dx - 58, fire.dy + 30)
          : _campSpots[i % _campSpots.length] +
                Offset(0, (i ~/ _campSpots.length) * 6.0);
      placed.add((feet, seated[i], i));
    }
    // The ones further back are drawn first, so the front ones overlap them.
    placed.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));

    for (final (feet, member, index) in placed) {
      final phase = seeded(index + 40);
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
      // A touch smaller further up the slope, for depth.
      final height = closeUp
          ? beanHeight
          : beanHeight * (0.92 + ((feet.dy - 175) / 45).clamp(0.0, 1.0) * 0.1);
      final towardFire = (fire.dx - feet.dx).sign;

      // The idle loop, every bean on its own beat: slow breathing, a gentle
      // sway, the eyes on the fire with a look at you or a neighbour now and
      // then. Who is ready gives a little hop; who is not waves once in a
      // while, the hand rising, two slow waves and down again.
      final beat = (t + phase) % 1;
      final breath = math.sin((t * 3 + phase) * math.pi * 2);
      final sway = leaving
          ? 0.0
          : math.sin((t * 2 + phase) * math.pi * 2) * 0.03;
      final hopBeat = (t * 2 + phase * 0.6) % 1;
      final hop = leaving
          ? math.sin(depart * math.pi * 14 + index).abs() * 0.08
          : member.ready && hopBeat > 0.42 && hopBeat < 0.54
          ? math.sin((hopBeat - 0.42) / 0.12 * math.pi) * 0.07
          : 0.0;
      final atYou = _window(beat, 0.12, 0.26);
      final aside = _window(beat, 0.58, 0.68);
      final look = leaving
          ? 1.0
          : towardFire * 0.8 * (1 - atYou) - towardFire * 1.6 * aside;
      final waveEnvelope = member.ready || leaving
          ? 0.0
          : _window((t + phase * 0.7) % 1, 0.3, 0.55);
      final wave = leaving
          ? 0.7
          : waveEnvelope *
                (0.7 + 0.3 * math.sin(((t + phase * 0.7) % 1) * math.pi * 16));

      // A soft shadow on the grass, smaller while in the air.
      final shadowWidth =
          height *
          member.look.kind.art.data.size.width /
          beanArtBlueHeight *
          (0.72 - hop * 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: position.translate(0, -height * 0.015),
          width: shadowWidth,
          height: height * 0.11,
        ),
        Paint()
          ..color = const Color(0x52000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * 0.025),
      );
      if (shade) {
        canvas.drawOval(
          Rect.fromCenter(
            center: position.translate(0, -height * 0.5),
            width: height * 1.5,
            height: height * 1.6,
          ),
          Paint()
            ..color = const Color(0x8C000000)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * 0.22),
        );
      }
      canvas.save();
      // The sway leans the whole bean about its feet.
      canvas.translate(position.dx, position.dy);
      canvas.rotate(sway);
      canvas.translate(-position.dx, -position.dy);
      paintBean(
        canvas,
        position,
        height,
        FlatPalette.beanFor(member.userId),
        BeanPose(
          bob: hop,
          breath: leaving ? 0 : breath,
          step: leaving ? math.sin(depart * math.pi * 14 + index) : 0,
          blink: ((t * 6 + index * 0.37) % 1) < 0.04,
          lookX: look.clamp(-1.0, 1.0),
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
      canvas.restore();
      if (!leaving) {
        final kindHeight =
            height * member.look.kind.art.data.size.height / beanArtBlueHeight;
        paintLabel(
          canvas,
          labelsAbove
              ? position.translate(0, -kindHeight - 9 / s - 6 - hop * height)
              : position.translate(0, 4),
          member.name,
          size: labelsAbove ? 7.5 / s : math.max(10 / s, 7),
          maxWidth: height * 1.6,
          weight: labelsAbove ? FontWeight.w400 : FontWeight.w600,
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

/// Where people stand round the fire, in the camp frame's units, in the
/// order they take them.
const _campSpots = [
  Offset(86, 178), // before the yellow tent (the designer's)
  Offset(238, 194), // right of the fire (the designer's)
  Offset(136, 204),
  Offset(274, 183),
  Offset(163, 227),
  Offset(96, 222),
  Offset(219, 236),
  Offset(303, 200),
];

/// 1 inside [from]..[to] on the 0..1 loop, 0 outside, with soft edges.
double _window(double x, double from, double to) {
  const ramp = 0.03;
  double smooth(double a, double b, double v) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  return smooth(from - ramp, from, x) * (1 - smooth(to, to + ramp, x));
}
