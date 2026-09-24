import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/application/points_status_text.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// Shown once, right after a run is marked complete: the «Маршрут пройден»
/// screen from the design. All figures come straight off the
/// [RouteExecution] the `complete` call already returned (routing snapshot
/// and server-computed points); nothing here does its own math.
class RouteExecutionSummaryScreen extends ConsumerWidget {
  const RouteExecutionSummaryScreen({required this.execution, super.key});

  final RouteExecution execution;

  /// Wall-clock time minus any paused stretches — "how long you actually
  /// walked," not "how long the run sat open."
  Duration? get _elapsed {
    final completedAt = execution.completedAt;
    if (completedAt == null) return null;
    final elapsed =
        completedAt.difference(execution.startedAt) -
        Duration(seconds: execution.pausedDurationSeconds);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Closes the recap and the finished run under it, back to the route.
  void _toRoute(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    if (router != null && router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = execution.routeId;
    final route = routeId == null
        ? null
        : ref.watch(routeDetailProvider(routeId)).asData?.value;
    final elapsed = _elapsed;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SettingsTopBar(
                arrowBack: true,
                onBack: () => Navigator.of(context).pop(),
                showSave: true,
                onSave: () => _toRoute(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 24),
                children: [
                  _FinishedCard(execution: execution),
                  const SizedBox(height: 20),
                  const Text(
                    'Статистика:',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          iconAsset: AppIconography.statRoutesCompleted,
                          value: _placesLabel(execution.completedStops),
                          label: 'Посещено',
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _StatBox(
                          iconAsset: AppIconography.statDistance,
                          value: formatDistanceKm(
                            execution.routing?.distanceMeters,
                          ),
                          label: 'Пройдено км.',
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _StatBox(
                          iconAsset: AppIconography.execAlarm,
                          value: elapsed == null
                              ? '—'
                              : '${elapsed.inMinutes} мин.',
                          label: 'Время в пути',
                        ),
                      ),
                    ],
                  ),
                  if (route != null) ...[
                    const SizedBox(height: 12),
                    RouteStaticMap(
                      staticMapUrl: route.staticMapUrl,
                      stops: route.stops,
                      geometry: route.geometry,
                      config: ref.watch(appConfigProvider),
                      height: 342,
                      footerLabel: execution.completedStops > 0
                          ? 'Вы на ${execution.completedStops} точке'
                          : routePointsLabel(route.stops.length),
                      pillFooter: true,
                      dashedLine: isWalkingMode(route.transportMode),
                      segments: route.segments,
                      completedFraction: 1,
                      completedStopPositions: {
                        for (final stop in execution.stops)
                          if (stop.isCompleted) stop.position,
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  _DarkButton(
                    label: 'На страницу маршрута',
                    onPressed: () => _toRoute(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «3 места», «1 место», «5 мест».
  static String _placesLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    final word = mod10 == 1 && mod100 != 11
        ? 'место'
        : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
        ? 'места'
        : 'мест';
    return '$count $word';
  }
}

const _accent = AppColors.accentBlue;
const _accentPale = Color(0xFFE3EDFB);
const _starFill = Color(0xFFC9DCF6);
const _hairline = Color(0xFFD6E4F7);
const _muted = Color(0xFF8E8E93);

/// The white card with the trophy, the title, the route name and the points.
class _FinishedCard extends StatelessWidget {
  const _FinishedCard({required this.execution});

  final RouteExecution execution;

  @override
  Widget build(BuildContext context) {
    final notice = pointsNotice(execution);
    final String? badge;
    if (notice != null && notice.replacesBadge) {
      badge = notice.badge;
    } else if (execution.awardedPoints > 0) {
      badge = '+${execution.awardedPoints} ТП';
    } else {
      badge = null;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.tile,
      ),
      child: CustomPaint(
        painter: const _CornerStarsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hairline,
                  border: Border.all(color: _accent, width: 1.6),
                ),
                alignment: Alignment.center,
                child: const AppAssetIcon(
                  AppIconography.finishCup,
                  size: 42,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 10),
              const _Hairline(),
              const SizedBox(height: 10),
              const Text(
                'Маршрут пройден!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                execution.routeName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 10),
              const _Hairline(),
              if (badge != null) ...[
                const SizedBox(height: 7),
                Center(
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: _accentPale,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          badge,
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Only for the exceptional points outcomes (on review, not
              // credited, part of the daily cap) until their own mockup.
              if (notice?.note case final note?) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: _muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(width: 257, height: 1, color: _hairline);
  }
}

/// Three little outlined stars in each corner of the card, as drawn.
class _CornerStarsPainter extends CustomPainter {
  const _CornerStarsPainter();

  // (from the corner horizontally, from the corner vertically, radius), pt.
  static const _top = [(23.0, 22.0, 8.0), (36.0, 30.0, 6.0), (26.0, 37.0, 6.0)];
  static const _bottom = [
    (19.0, 27.0, 5.0),
    (29.0, 21.0, 4.5),
    (21.0, 15.0, 5.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _starFill;
    final stroke = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    void star(double cx, double cy, double r) {
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final radius = i.isEven ? r : r * 0.45;
        final angle = -math.pi / 2 + i * math.pi / 5;
        final point = Offset(
          cx + radius * math.cos(angle),
          cy + radius * math.sin(angle),
        );
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, stroke);
    }

    for (final (dx, dy, r) in _top) {
      star(dx, dy, r);
      star(size.width - dx, dy, r);
    }
    for (final (dx, dy, r) in _bottom) {
      star(dx, size.height - dy, r);
      star(size.width - dx, size.height - dy, r);
    }
  }

  @override
  bool shouldRepaint(_CornerStarsPainter oldDelegate) => false;
}

/// One of the three «Статистика» tiles, drawn like the profile's.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.iconAsset,
    required this.value,
    required this.label,
  });

  final String iconAsset;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        height: 45,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.tile,
        ),
        child: Row(
          children: [
            AppAssetIcon(iconAsset, size: 22, color: AppColors.profileStatIcon),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        color: AppColors.primaryInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryInk,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
