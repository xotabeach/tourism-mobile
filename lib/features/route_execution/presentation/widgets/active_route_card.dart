import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/route_execution/application/home_active_run.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/routing/app_router.dart';

// DESIGN-12 №1 colours, sampled from the mockup.
const _running = Color(0xFF34C759);
const _paused = Color(0xFFFFCC00);
const _stale = Color(0xFFFF383C);
const _offline = Color(0xFF4D4D4D);
const _accent = Color(0xFF1E71CA);

/// A run in progress on the home screen, in place of the «Подбери маршрут»
/// banner and the same size (FRONTEND-34, spec 13).
class ActiveRouteCard extends ConsumerStatefulWidget {
  const ActiveRouteCard({required this.state, super.key});

  final HomeActiveRun state;

  @override
  ConsumerState<ActiveRouteCard> createState() => _ActiveRouteCardState();
}

class _ActiveRouteCardState extends ConsumerState<ActiveRouteCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Time on the route ticks by the minute, as on the run screen.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _open() {
    final routeId = widget.state.run.routeId;
    if (routeId == null) {
      // A run whose route is gone has no run screen to go back to.
      context.goNamed(AppRouteNames.myRoutes);
      return;
    }
    unawaited(context.push('/routes/$routeId/execution?open=1'));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final run = state.run;
    final now = DateTime.now();
    final status = _status(state, now);
    final minutes = run.elapsed(now).inMinutes;
    final next = _nextStopName(run);
    final stats = _stats(run);
    return Semantics(
      button: true,
      label:
          'Активный маршрут «${run.routeName}», ${status.label}, '
          '$stats, продолжить',
      excludeSemantics: true,
      child: AppPressableScale(
        borderRadius: AppRadii.card,
        onTap: _open,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            height: 246,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImages.coverImage(
                  config: ref.watch(appConfigProvider),
                  coverImageUrl: run.routeCoverUrl,
                  fallbackSeed: run.routeId ?? run.id,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0xB3000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _StatusPill(status: status),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const AppAssetIcon(
                            AppIconography.runClock,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$minutes мин',
                            style: const TextStyle(
                              fontFamily: AppFonts.rubik,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // The mockup's title box is narrower than the card, so
                      // a long name wraps early like «…гнездо / и царская
                      // тропа».
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 215),
                        child: Text(
                          run.routeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ProgressBar(value: run.progress),
                      const SizedBox(height: 8),
                      Text(
                        stats,
                        style: TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _accent,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: const AppAssetIcon(
                              AppIconography.runPin,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              // Wraps as early as the mockup's text box.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: Text(
                                  next,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.rubik,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    height: 1.25,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AppGlassCircle(
                            dimension: 40,
                            blur: 12,
                            fillColor: Colors.white.withValues(alpha: 0.45),
                            borderColor: Colors.white.withValues(alpha: 0.3),
                            contentColor: Colors.white,
                            child: const AppAssetIcon(
                              AppIconography.arrow,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunStatus {
  const _RunStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final String icon;
}

/// No network wins: the rest may be out of date. Then a day without
/// activity, then the pause.
_RunStatus _status(HomeActiveRun state, DateTime now) {
  if (state.offline) {
    return const _RunStatus('Нет сети', _offline, AppIconography.runOffline);
  }
  if (state.isStale(now)) {
    return const _RunStatus(
      'Неактивен более суток',
      _stale,
      AppIconography.runClock,
    );
  }
  if (state.run.status == RouteExecutionStatus.paused) {
    return const _RunStatus('На паузе', _paused, AppIconography.runPause);
  }
  return const _RunStatus('Идёт прохождение', _running, AppIconography.runPlay);
}

String _nextStopName(RouteExecution run) {
  for (final stop in run.stops) {
    if (!stop.isCompleted) return 'Дальше: ${stop.placeName}';
  }
  return 'Все точки отмечены';
}

/// «3 из 7 точек • 1,8 из 4,2 км»: the kilometres are the planned legs up to
/// the marked stops out of the whole route (spec 13, D4) — no track is
/// recorded, so it never says «пройдено». Without lengths, points only.
String _stats(RouteExecution run) {
  final total = run.totalStops;
  final pointsWord = total % 10 == 1 && total % 100 != 11 ? 'точки' : 'точек';
  final points = '${run.completedStops} из $total $pointsWord';
  final routeMeters = run.routing?.distanceMeters;
  if (routeMeters == null || routeMeters <= 0) return points;
  var doneMeters = 0;
  for (final stop in run.stops) {
    if (stop.isCompleted) doneMeters += stop.legDistanceMeters ?? 0;
  }
  return '$points • ${_km(doneMeters)} из ${_km(routeMeters)} км';
}

String _km(int meters) {
  final km = meters / 1000;
  final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _RunStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAssetIcon(status.icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.55)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: _accent),
            ),
          ],
        ),
      ),
    );
  }
}
