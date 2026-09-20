import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

/// Wording for the points badge of a finished run, or null for the ordinary
/// case - then the summary keeps its regular design untouched.
///
/// Only exceptional outcomes get text: points held for review, cancelled by an
/// operator, or limited by a repeat/daily rule. The limits themselves are not
/// spelled out here because the server owns and can change them.
class PointsNotice {
  const PointsNotice({
    required this.badge,
    this.note,
    this.replacesBadge = true,
  });

  final String badge;
  final String? note;

  /// False when the usual "+N" badge stays and only [note] is added.
  final bool replacesBadge;
}

PointsNotice? pointsNotice(RouteExecution execution) {
  switch (execution.pointsStatus) {
    case RoutePointsStatus.held:
      return PointsNotice(
        badge: 'Очки на проверке (${execution.heldPoints})',
        note: 'Команда проверит прохождение и сообщит о решении.',
      );
    case RoutePointsStatus.rejected:
      return const PointsNotice(badge: 'Очки не начислены');
    case RoutePointsStatus.awarded:
    case RoutePointsStatus.none:
      break;
  }
  switch (execution.pointsReason) {
    case 'route_cooldown':
      return const PointsNotice(
        badge: 'Очки не начислены',
        note: 'Этот маршрут уже засчитывался недавно.',
      );
    case 'daily_cap':
      return execution.awardedPoints > 0
          ? const PointsNotice(
              badge: '',
              note: 'Достигнут дневной лимит очков: начислена только часть.',
              replacesBadge: false,
            )
          : const PointsNotice(
              badge: 'Очки не начислены',
              note: 'Достигнут дневной лимит очков.',
            );
  }
  return null;
}
