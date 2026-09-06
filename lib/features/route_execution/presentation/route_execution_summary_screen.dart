import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// Shown once, right after a run is marked complete — a small recap instead
/// of just flipping the status label in place. All figures come straight off
/// the [RouteExecution] the `complete` call already returned (routing
/// snapshot + server-computed points); nothing here does its own math.
class RouteExecutionSummaryScreen extends StatelessWidget {
  const RouteExecutionSummaryScreen({required this.execution, super.key});

  final RouteExecution execution;

  Duration? get _elapsed {
    final completedAt = execution.completedAt;
    if (completedAt == null) return null;
    final elapsed = completedAt.difference(execution.startedAt);
    return elapsed.isNegative ? null : elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final routing = execution.routing;
    final elapsed = _elapsed;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 56,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Маршрут пройден!',
                        textAlign: TextAlign.center,
                        style: AppTypography.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        execution.routeName,
                        textAlign: TextAlign.center,
                        style: AppTypography.greetingSubtitle.copyWith(
                          color: AppColors.secondaryInk,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (execution.awardedPoints > 0) ...[
                        _PointsBadge(points: execution.awardedPoints),
                        const SizedBox(height: 24),
                      ],
                      _SummaryStatsGrid(
                        elapsed: elapsed,
                        distanceMeters: routing?.distanceMeters,
                        elevationGainMeters: routing?.elevationGainMeters,
                        completedStops: execution.completedStops,
                        totalStops: execution.totalStops,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Готово'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          '+$points путевых очков',
          style: AppTypography.button.copyWith(color: AppColors.accentBlue),
        ),
      ),
    );
  }
}

class _SummaryStatsGrid extends StatelessWidget {
  const _SummaryStatsGrid({
    required this.elapsed,
    required this.distanceMeters,
    required this.elevationGainMeters,
    required this.completedStops,
    required this.totalStops,
  });

  final Duration? elapsed;
  final int? distanceMeters;
  final int? elevationGainMeters;
  final int completedStops;
  final int totalStops;

  static String _formatElapsed(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    if (hours > 0) return '$hours ч $minutes мин';
    return '$minutes мин';
  }

  static String _formatDistance(int meters) {
    if (meters < 1000) return '$meters м';
    return '${(meters / 1000).toStringAsFixed(1)} км';
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTile>[
      _StatTile(
        icon: Icons.checklist_rounded,
        label: 'Точки',
        value: '$completedStops из $totalStops',
      ),
      if (elapsed != null)
        _StatTile(
          icon: Icons.timer_outlined,
          label: 'Время',
          value: _formatElapsed(elapsed!),
        ),
      if (distanceMeters != null && distanceMeters! > 0)
        _StatTile(
          icon: Icons.route_outlined,
          label: 'Расстояние',
          value: _formatDistance(distanceMeters!),
        ),
      if (elevationGainMeters != null && elevationGainMeters! > 0)
        _StatTile(
          icon: Icons.terrain_outlined,
          label: 'Набор высоты',
          value: '$elevationGainMeters м',
        ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.accentBlue),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTypography.settingsRowTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: AppTypography.settingsRowSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}
