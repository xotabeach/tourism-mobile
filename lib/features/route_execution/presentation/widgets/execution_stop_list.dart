import 'package:flutter/material.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_chrome.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

class ExecutionStopRow extends StatelessWidget {
  const ExecutionStopRow({
    super.key,
    required this.stop,
    this.isNext = false,
    required this.busy,
    required this.enabled,
    required this.onComplete,
    this.onUndo,
    this.travelSummary,
  });

  final RouteExecutionStop stop;

  /// The stop being walked to now: drawn with the accent of the leg line
  /// (FRONTEND-22).
  final bool isNext;

  /// «на машине 3,3 км · пешком 1,4 км от парковки» for a leg that is not
  /// one plain way (spec 14b).
  final String? travelSummary;
  final bool busy;
  final bool enabled;
  final VoidCallback onComplete;

  /// Set only for the latest marked stop: tapping its tick takes it back.
  final VoidCallback? onUndo;

  String get _subtitle {
    final parts = [
      // Leg length, with the expected time when there is one.
      ?formatLegLabel(stop.legDistanceMeters, stop.legEstimateSeconds) ??
          (stop.legDistanceMeters == null
              ? null
              : formatDistanceKm(stop.legDistanceMeters)),
      ?travelSummary,
      if (stop.isOptional) 'Можно пропустить',
    ];
    if (isNext) parts.insert(0, 'Следующая');
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final done = stop.isCompleted;
    // A mark made offline that the server never got (DESIGN-4, №3): a red
    // cross in place of the ring and a short red note, tap marks it again.
    final undelivered = stop.undelivered && !done;
    final subtitle = _subtitle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 47,
      // No inset: the tint runs from the number circle to the mark ring as
      // one pill, and the row keeps the full width its content needs.
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.accentBlue.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isNext ? AppColors.accentBlue : AppColors.primaryInk,
            ),
            alignment: Alignment.center,
            child: Text(
              '${stop.position}',
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 13,
                      fontWeight: isNext ? FontWeight.w500 : FontWeight.w400,
                      height: 1.2,
                      color: isNext
                          ? AppColors.accentBlue
                          : ExecutionColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (undelivered && !busy) ...[
            const ExcludeSemantics(
              child: Text(
                'Что-то пошло не так,\nпопробуйте ещё раз.',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: ExecutionColors.error,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          ExecutionStopMark(
            done: done,
            undelivered: undelivered,
            busy: busy,
            placeName: stop.placeName,
            onTap: busy
                ? null
                : done
                ? onUndo
                : enabled
                ? onComplete
                : null,
          ),
        ],
      ),
    );
  }
}

/// The round mark on the right of a stop: an empty ring to tap when the
/// stop is reached, filled with a tick once it is.
class ExecutionStopMark extends StatelessWidget {
  const ExecutionStopMark({
    super.key,
    required this.done,
    required this.busy,
    required this.placeName,
    required this.onTap,
    this.undelivered = false,
  });

  final bool done;
  final bool undelivered;
  final bool busy;
  final String placeName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: !done || onTap != null,
      checked: done,
      enabled: onTap != null,
      label: undelivered
          ? 'Отметка «$placeName» не доставлена, отметить заново'
          : !done
          ? 'Отметить «$placeName»'
          : onTap != null
          ? '«$placeName» отмечена, снять отметку'
          : '«$placeName» отмечена',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: undelivered && !busy
                ? Image.asset(
                    AppIconography.execUndelivered,
                    width: 31,
                    height: 31,
                  )
                : Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primaryInk : Colors.transparent,
                      border: done
                          ? null
                          : Border.all(color: ExecutionColors.ring, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
          ),
        ),
      ),
    );
  }
}

class ExecutionEmptyStopsCard extends StatelessWidget {
  const ExecutionEmptyStopsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Маршрут можно начать. Остановки синхронизируются после ответа сервера.',
        ),
      ),
    );
  }
}
