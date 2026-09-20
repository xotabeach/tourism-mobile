import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/application/points_status_text.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';

RouteExecution _done({
  RoutePointsStatus status = RoutePointsStatus.awarded,
  String? reason,
  int awarded = 0,
  int held = 0,
}) => RouteExecution(
  id: 'e',
  routeName: 'M',
  status: RouteExecutionStatus.completed,
  startedAt: DateTime.utc(2026, 9, 20),
  totalStops: 0,
  completedStops: 0,
  requiredStops: 0,
  completedRequiredStops: 0,
  stops: const [],
  pointsStatus: status,
  pointsReason: reason,
  awardedPoints: awarded,
  heldPoints: held,
);

void main() {
  test('an ordinary completion has no notice, so the design stays as is', () {
    expect(pointsNotice(_done(awarded: 50)), isNull);
    expect(pointsNotice(_done(status: RoutePointsStatus.none)), isNull);
  });

  test('held and rejected replace the badge', () {
    final held = pointsNotice(_done(status: RoutePointsStatus.held, held: 40))!;
    expect(held.badge, 'Очки на проверке (40)');
    expect(held.replacesBadge, isTrue);
    expect(
      pointsNotice(_done(status: RoutePointsStatus.rejected))!.badge,
      'Очки не начислены',
    );
  });

  test('cooldown and daily cap explain themselves', () {
    expect(pointsNotice(_done(reason: 'route_cooldown'))!.note, isNotNull);
    final none = pointsNotice(_done(reason: 'daily_cap'))!;
    expect(none.badge, 'Очки не начислены');
    final partial = pointsNotice(_done(reason: 'daily_cap', awarded: 20))!;
    expect(partial.replacesBadge, isFalse);
    expect(partial.note, contains('дневной лимит'));
  });

  test('anti-fraud notification kinds are recognised', () {
    expect(
      inboxNotificationKindFromApi('antifraud_flagged'),
      InboxNotificationKind.antifraudFlagged,
    );
    expect(
      inboxNotificationKindFromApi('antifraud_blocked'),
      InboxNotificationKind.antifraudBlocked,
    );
    expect(
      inboxNotificationKindFromApi('antifraud_points_decision'),
      InboxNotificationKind.antifraudPointsDecision,
    );
    expect(inboxNotificationKindFromApi('nope'), InboxNotificationKind.unknown);
  });
}
