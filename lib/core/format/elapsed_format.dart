/// Time on the way as people read it (FRONTEND-94): «45 мин.» under an
/// hour, «4 ч 12 мин.» under a day, «3 д 23 ч» beyond. A two-day route used
/// to show «5730 мин.».
///
/// [dot] ends the minutes with a period, as the run screens write them;
/// the compact home card goes without.
String formatElapsed(Duration elapsed, {bool dot = true}) {
  final minutesWord = dot ? 'мин.' : 'мин';
  final total = elapsed.isNegative ? 0 : elapsed.inMinutes;
  final days = total ~/ (24 * 60);
  final hours = (total ~/ 60) % 24;
  final minutes = total % 60;
  if (days > 0) return hours > 0 ? '$days д $hours ч' : '$days д';
  if (hours > 0) {
    return minutes > 0 ? '$hours ч $minutes $minutesWord' : '$hours ч';
  }
  return '$minutes $minutesWord';
}
