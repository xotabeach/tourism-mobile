import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/mock_companions_repository.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_group_screen.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/campfire_scene.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/group_postcard.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/mountain_route.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';

import '../../support/test_overrides.dart';

// FRONTEND-63: groups of companions in the app (spec 11b).

Map<String, dynamic> _groupJson({
  String status = 'gathering',
  String? myState = 'invited',
  bool organizer = false,
}) => {
  'id': 'g1',
  'route_id': 'route-1',
  'route_name': 'Классика Южного берега',
  'status': status,
  'organizer_user_id': 'anna',
  'organizer_display_name': 'Анна',
  'is_organizer': organizer,
  'max_members': 8,
  'my_state': myState,
  'join_code': myState == 'joined' ? 'ABC234' : null,
  'members': [
    {
      'user_id': 'anna',
      'display_name': 'Анна',
      'state': 'joined',
      'is_organizer': true,
    },
    {'user_id': 'mock-user', 'display_name': 'Никита', 'state': myState},
  ],
  'joined_count': 2,
  'created_at': '2026-10-12T10:00:00Z',
  'started_at': status == 'gathering' ? null : '2026-10-12T10:30:00Z',
};

class _Repo extends MockCompanionsRepository {
  _Repo(this.group, {this.walk});

  CompanionGroup group;
  final CompanionProgress? walk;
  final answers = <bool>[];
  final left = <String>[];

  @override
  Future<CompanionGroup?> removeMember(String groupId, String userId) async {
    left.add(userId);
    return null;
  }

  @override
  Future<CompanionGroup> get(String groupId) async => group;

  @override
  Future<CompanionProgress> progress(String groupId) async => walk!;

  @override
  Future<CompanionGroup> respond(String groupId, {required bool accept}) async {
    answers.add(accept);
    return group = CompanionGroup.fromJson(
      _groupJson(myState: accept ? 'joined' : 'declined'),
    );
  }
}

Future<void> _open(WidgetTester tester, CompanionsRepository repo) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        companionsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: CompanionGroupScreen(groupId: 'g1')),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _close(WidgetTester tester) async {
  // Stops the polling timer and the scene's animation.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  test('a group and its progress are read from the server', () {
    final group = CompanionGroup.fromJson(_groupJson(myState: 'joined'));
    expect(group.isInside, isTrue);
    expect(group.joinCode, 'ABC234');
    expect(group.joined.map((m) => m.displayName), ['Анна', 'Никита']);
    final progress = CompanionProgress.fromJson({
      'group_id': 'g1',
      'status': 'settled',
      'leaderboard_hidden': false,
      'stops': [
        {'position': 1, 'place_name': 'Ротонда', 'first_user_id': 'anna'},
      ],
      'members': [
        {
          'user_id': 'anna',
          'display_name': 'Анна',
          'status': 'finished',
          'last_position': 1,
          'marks': [
            {
              'position': 1,
              'marked_at': '2026-10-12T11:00:00Z',
              'offline': true,
            },
          ],
          'reached': true,
        },
      ],
      'summary': {
        'settled': true,
        'started_count': 1,
        'reached_count': 1,
        'everyone_reached': true,
        'distance_meters': 5200,
        'total_seconds': 7260,
        'first_finisher_user_id': 'anna',
      },
    });
    expect(progress.status, CompanionGroupStatus.settled);
    expect(progress.members.single.status, CompanionRunStatus.finished);
    expect(progress.members.single.marks.single.offline, isTrue);
    expect(progress.summary.distanceMeters, 5200);
  });

  test('a bean keeps its colour on every screen', () {
    expect(FlatPalette.beanFor('anna'), FlatPalette.beanFor('anna'));
    expect(FlatPalette.beans, contains(FlatPalette.beanFor('mock-user')));
  });

  test('an offline start remembers its group', () {
    final entry = RouteExecutionOutboxEntry(
      id: 'local-1_start',
      executionId: 'local-1',
      routeId: 'route-1',
      action: RouteExecutionAction.start,
      createdAt: DateTime.utc(2026, 10, 12, 10, 31),
      companionGroupId: 'g1',
    );
    final back = RouteExecutionOutboxEntry.fromJson(entry.toJson());
    expect(back.companionGroupId, 'g1');
    expect(back.incrementAttempt().companionGroupId, 'g1');
  });

  testWidgets('an invitation is answered from the camp', (tester) async {
    final repo = _Repo(CompanionGroup.fromJson(_groupJson()));
    await _open(tester, repo);
    expect(find.byType(CampfireScene), findsOneWidget);
    expect(find.textContaining('Анна зовёт вас'), findsOneWidget);
    // The invitee does not see the code yet.
    expect(find.text('Код группы:'), findsNothing);
    await tester.tap(find.text('Пойду'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.answers, [true]);
    expect(find.text('Готов'), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Попутчики:'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the organizer gathers people and starts only with company', (
    tester,
  ) async {
    final repo = MockCompanionsRepository();
    final group = await repo.create('route-1');
    await _open(tester, _Pass(repo, group.id));
    expect(find.text('Совместный маршрут:'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, 'Выйти на тропу');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(find.text('Позовите хотя бы одного попутчика'), findsOneWidget);

    await tester.tap(find.text('Позвать друзей'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Позвать').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Позван'), findsOneWidget);
    Navigator.of(tester.element(find.text('Позван'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ждём ответа'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('on the way: the mountain, who is where', (tester) async {
    final repo = _Repo(
      CompanionGroup.fromJson(_groupJson(status: 'started', myState: 'joined')),
      walk: const CompanionProgress(
        groupId: 'g1',
        status: CompanionGroupStatus.started,
        stops: [
          CompanionStop(
            position: 1,
            placeName: 'Ротонда',
            firstUserId: 'anna',
            distanceFromStartMeters: 0,
          ),
          CompanionStop(
            position: 2,
            placeName: 'Маяк',
            distanceFromStartMeters: 3500,
          ),
        ],
        members: [
          CompanionMemberProgress(
            userId: 'anna',
            displayName: 'Анна',
            status: CompanionRunStatus.walking,
            lastPosition: 2,
          ),
          CompanionMemberProgress(
            userId: 'mock-user',
            displayName: 'Никита',
            status: CompanionRunStatus.notStarted,
          ),
        ],
        summary: CompanionSummary(
          settled: false,
          startedCount: 1,
          reachedCount: 0,
          everyoneReached: false,
        ),
      ),
    );
    await _open(tester, repo);
    expect(find.text('Группа в пути:'), findsOneWidget);
    expect(find.byType(MountainRoute), findsOneWidget);
    expect(find.text('Начать прохождение'), findsOneWidget);
    expect(find.text('Участники маршрута:'), findsOneWidget);
    expect(find.text('3,5 км от старта • Маяк'), findsOneWidget);
    expect(find.text('Ещё не вышел'), findsOneWidget);
    // The postcard waits for the end.
    expect(find.byType(GroupPostcard), findsNothing);
    await _close(tester);
  });

  testWidgets('on the way one can still leave, after a question', (
    tester,
  ) async {
    final repo = _Repo(
      CompanionGroup.fromJson(_groupJson(status: 'started', myState: 'joined')),
      walk: const CompanionProgress(
        groupId: 'g1',
        status: CompanionGroupStatus.started,
        stops: [CompanionStop(position: 1, placeName: 'Ротонда')],
        members: [
          CompanionMemberProgress(
            userId: 'mock-user',
            displayName: 'Никита',
            status: CompanionRunStatus.walking,
          ),
        ],
        summary: CompanionSummary(
          settled: false,
          startedCount: 1,
          reachedCount: 0,
          everyoneReached: false,
        ),
      ),
    );
    await _open(tester, repo);
    final leave = find.text('Сойти с дистанции');
    await tester.ensureVisible(leave);
    await tester.pump();
    await tester.tap(leave);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Выйти из группы?'), findsOneWidget);

    await tester.tap(find.text('Остаться'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.left, isEmpty);

    await tester.tap(leave);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Выйти'));
    await tester.pump();
    expect(repo.left, ['mock-user']);
    await _close(tester);
  });
}

/// The mock repository as is, but always reading this one group.
class _Pass extends MockCompanionsRepository {
  _Pass(this.inner, this.id);

  final MockCompanionsRepository inner;
  final String id;

  @override
  Future<CompanionGroup> get(String groupId) => inner.get(id);

  @override
  Future<CompanionGroup> invite(String groupId, String userId) =>
      inner.invite(id, userId);
}
