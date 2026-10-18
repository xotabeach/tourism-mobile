import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/home_lobby_card.dart';
import 'package:tourism_mobile/features/home/presentation/home_top_card.dart';
import 'package:tourism_mobile/features/route_execution/application/home_active_run.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/active_route_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

// FRONTEND-73: a gathering group is not hidden by a paused run elsewhere.

HomeActiveRun _run({String routeId = 'route-1'}) => HomeActiveRun(
  offline: false,
  run: RouteExecution(
    id: 'run-1',
    routeId: routeId,
    routeName: 'Ласточкино гнездо',
    status: RouteExecutionStatus.paused,
    startedAt: DateTime(2026, 10, 12, 10),
    totalStops: 3,
    completedStops: 1,
    requiredStops: 3,
    completedRequiredStops: 1,
    stops: const [],
  ),
);

CompanionGroup _lobby({
  String status = 'gathering',
  String myState = 'joined',
  String routeId = 'route-2',
}) => CompanionGroup.fromJson({
  'id': 'g1',
  'route_id': routeId,
  'route_name': 'Классика Южного берега',
  'status': status,
  'organizer_user_id': 'anna',
  'organizer_display_name': 'Анна',
  'is_organizer': false,
  'max_members': 6,
  'my_state': myState,
  'members': const <Map<String, dynamic>>[],
  'joined_count': 1,
  'created_at': '2026-10-12T10:00:00Z',
});

void main() {
  test('nothing going on: the banner', () {
    expect(homeTopCard(), isA<BuildRouteBanner>());
  });

  test('a gathering group wins over a paused run elsewhere', () {
    expect(homeTopCard(run: _run(), lobby: _lobby()), isA<HomeLobbyCard>());
  });

  test('an invitation wins over a run too', () {
    expect(
      homeTopCard(
        run: _run(),
        lobby: _lobby(status: 'started', myState: 'invited'),
      ),
      isA<HomeLobbyCard>(),
    );
  });

  test('the group on its way: the run card with a group pill', () {
    final card = homeTopCard(
      run: _run(routeId: 'route-2'),
      lobby: _lobby(status: 'started'),
    );
    expect(card, isA<ActiveRouteCard>());
    expect((card as ActiveRouteCard).groupId, 'g1');
  });

  test('a run on another route has no group pill', () {
    final card = homeTopCard(
      run: _run(),
      lobby: _lobby(status: 'started'),
    );
    expect((card as ActiveRouteCard).groupId, isNull);
  });

  test('a group on its way without a run here: the lobby card', () {
    expect(homeTopCard(lobby: _lobby(status: 'started')), isA<HomeLobbyCard>());
  });
}
