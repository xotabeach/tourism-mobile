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
  final limits = execution.antifraud;
  switch (execution.pointsReason) {
    case 'route_cooldown':
      final days = limits?.routeCooldownDays;
      return PointsNotice(
        badge: 'Очки не начислены',
        note: days == null
            ? 'Этот маршрут уже засчитывался недавно.'
            : 'Повтор маршрута раньше чем через ${_days(days)} очков не даёт.',
      );
    case 'daily_cap':
      final cap = limits?.dailyPointsCap;
      final limit = cap == null
          ? 'Достигнут дневной лимит очков'
          : 'Достигнут дневной лимит очков ($cap)';
      return execution.awardedPoints > 0
          ? PointsNotice(
              badge: '',
              note: '$limit: начислена только часть.',
              replacesBadge: false,
            )
          : PointsNotice(badge: 'Очки не начислены', note: '$limit.');
  }
  return null;
}

/// "14 дней", "21 день", "2 дня".
String _days(int n) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  final word = (mod100 >= 11 && mod100 <= 14)
      ? 'дней'
      : mod10 == 1
      ? 'день'
      : (mod10 >= 2 && mod10 <= 4)
      ? 'дня'
      : 'дней';
  return '$n $word';
}
