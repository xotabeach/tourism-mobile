import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// The group's card at the finish (spec 11b D17): everyone on the summit
/// with a flag, the kilometres and the time, and stickers for who got where
/// first. It leaves the app, so it carries names only, never times of
/// single marks; until the result is fixed it says «ещё идут».
class GroupPostcard extends StatelessWidget {
  const GroupPostcard({
    required this.routeName,
    required this.progress,
    this.hiddenUserIds = const {},
    super.key,
  });

  final String routeName;
  final CompanionProgress progress;

  /// People who asked to stay off the card.
  final Set<String> hiddenUserIds;

  @override
  Widget build(BuildContext context) {
    final summary = progress.summary;
    final shown = [
      for (final member in progress.members)
        if (!hiddenUserIds.contains(member.userId)) member,
    ];
    final names = {for (final m in progress.members) m.userId: m.displayName};
    final stickers = <String>[
      if (!progress.leaderboardHidden)
        for (final stop in progress.stops)
          if (stop.firstUserId != null &&
              !hiddenUserIds.contains(stop.firstUserId) &&
              names[stop.firstUserId] != null)
            'Первым на «${stop.placeName}»: ${names[stop.firstUserId]}',
      if (!progress.leaderboardHidden &&
          summary.firstFinisherUserId != null &&
          !hiddenUserIds.contains(summary.firstFinisherUserId))
        'Первым на финише: ${names[summary.firstFinisherUserId] ?? ''}',
    ];
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FlatPalette.paper,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.settled ? 'Мы прошли вместе' : 'Идём вместе, ещё идут',
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FlatPalette.flameOuter,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                routeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: FlatPalette.ink,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SummitPainter(
                          [for (final m in shown) m.userId],
                          {
                            for (final m in shown)
                              m.userId: BeanLook.forUser(
                                m.userId,
                                hat: m.beanHat,
                                kind: m.beanKind,
                                outfit: m.beanOutfit,
                              ),
                          },
                          {
                            for (final m in shown)
                              if (m.status == CompanionRunStatus.finished)
                                m.userId,
                          },
                        ),
                      ),
                    ),
                    for (var i = 0; i < stickers.length && i < 3; i++)
                      Positioned(
                        left: i.isEven ? 0 : null,
                        right: i.isOdd ? 0 : null,
                        top: 4.0 + i * 34,
                        child: _Sticker(
                          text: stickers[i],
                          color: FlatPalette
                              .beans[(i * 3 + 1) % FlatPalette.beans.length],
                          tilt: i.isEven ? -0.05 : 0.05,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Figure(
                    value: summary.distanceMeters == null
                        ? '—'
                        : (summary.distanceMeters! / 1000)
                              .toStringAsFixed(1)
                              .replaceAll('.', ','),
                    label: 'км вместе',
                  ),
                  _Figure(
                    value: _duration(summary.totalSeconds),
                    label: 'в пути',
                  ),
                  _Figure(
                    value:
                        '${summary.reachedCount} из ${progress.members.length}',
                    label: summary.everyoneReached ? 'дошли все' : 'дошли',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(int? seconds) {
    if (seconds == null) return '—';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes мин';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours ч' : '$hours ч $rest мин';
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: FlatPalette.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 12,
            color: Color(0xFF6B6B7B),
          ),
        ),
      ],
    ),
  );
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.text, required this.color, required this.tilt});

  final String text;
  final Color color;
  final double tilt;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: tilt,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FlatPalette.white,
        ),
      ),
    ),
  );
}

class _SummitPainter extends CustomPainter {
  _SummitPainter(this.userIds, this.hats, this.finished);

  final List<String> userIds;
  final Map<String, BeanLook> hats;
  final Set<String> finished;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF8FD3F4),
    );
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.2),
      h * 0.09,
      Paint()..color = FlatPalette.flameCore,
    );
    final back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.7)
      ..lineTo(w * 0.22, h * 0.48)
      ..lineTo(w * 0.42, h * 0.66)
      ..lineTo(w, h * 0.55)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF5FA8A0));
    final summit = Path()
      ..moveTo(w * 0.05, h)
      ..lineTo(w * 0.5, h * 0.36)
      ..lineTo(w * 0.95, h)
      ..close();
    canvas.drawPath(summit, Paint()..color = FlatPalette.ground);
    final snow = Path()
      ..moveTo(w * 0.5, h * 0.36)
      ..lineTo(w * 0.42, h * 0.47)
      ..lineTo(w * 0.47, h * 0.45)
      ..lineTo(w * 0.5, h * 0.49)
      ..lineTo(w * 0.53, h * 0.45)
      ..lineTo(w * 0.58, h * 0.47)
      ..close();
    canvas.drawPath(snow, Paint()..color = FlatPalette.white);
    // The flag on top.
    final pole = Offset(w * 0.5, h * 0.36);
    canvas.drawLine(
      pole,
      pole.translate(0, -h * 0.2),
      Paint()
        ..color = FlatPalette.ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pole.dx, pole.dy - h * 0.2)
        ..lineTo(pole.dx + h * 0.14, pole.dy - h * 0.16)
        ..lineTo(pole.dx, pole.dy - h * 0.12)
        ..close(),
      Paint()..color = FlatPalette.flameOuter,
    );

    // Everyone stands on the slope, a happy face for those who made it.
    final count = userIds.length;
    final beanHeight = math.min(h * 0.26, w / math.max(count, 1) * 0.9);
    for (var i = 0; i < count; i++) {
      var x = w * (0.14 + 0.72 * (count == 1 ? 0.3 : i / (count - 1)));
      // Nobody stands on the very top: the flag is there.
      if ((x - w / 2).abs() < w * 0.16) {
        x = w / 2 + (i < count / 2 ? -1 : 1) * w * 0.16;
      }
      final slopeY = h * 0.36 + (x - w * 0.5).abs() / (w * 0.45) * h * 0.64;
      paintBean(
        canvas,
        Offset(x, math.min(h * 0.98, slopeY + beanHeight * 0.35)),
        beanHeight,
        FlatPalette.beanFor(userIds[i]),
        BeanPose(
          look: hats[userIds[i]] ?? BeanLook.forUser(userIds[i]),
          wave: finished.contains(userIds[i]) && i.isEven ? 0.9 : 0,
          happy: finished.contains(userIds[i]),
          lookX: x < w / 2 ? 1 : -1,
        ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SummitPainter old) =>
      old.userIds != userIds || old.finished != finished;
}
