import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/mock_companions_repository.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/home_lobby_card.dart';
import 'package:tourism_mobile/features/companions/presentation/my_groups_list.dart';

import '../../support/test_overrides.dart';

// FRONTEND-73: the way back to a group left for later.

CompanionGroup _group({
  String id = 'g1',
  String status = 'gathering',
  String? myState = 'joined',
  bool organizer = true,
  String route = 'Классика Южного берега',
}) => CompanionGroup.fromJson({
  'id': id,
  'route_id': 'route-$id',
  'route_name': route,
  'status': status,
  'organizer_user_id': organizer ? 'mock-user' : 'anna',
  'organizer_display_name': organizer ? 'Никита' : 'Анна',
  'is_organizer': organizer,
  'max_members': 6,
  'my_state': myState,
  'members': [
    {
      'user_id': organizer ? 'mock-user' : 'anna',
      'display_name': organizer ? 'Никита' : 'Анна',
      'state': 'joined',
      'is_organizer': true,
    },
    if (!organizer)
      {'user_id': 'mock-user', 'display_name': 'Никита', 'state': myState},
    {'user_id': 'gleb', 'display_name': 'Глеб', 'state': 'joined'},
  ],
  'joined_count': 2,
  'created_at': '2026-10-12T10:00:00Z',
});

class _Repo extends MockCompanionsRepository {
  _Repo(this.groups);

  final List<CompanionGroup> groups;

  @override
  Future<List<CompanionGroup>> myGroups() async => groups;
}

void main() {
  group('activeLobbyOf', () {
    test('picks a live group the person is in or invited to', () {
      expect(activeLobbyOf([_group(status: 'settled')]), isNull);
      expect(
        activeLobbyOf([
          _group(id: 'asked', myState: 'requested', organizer: false),
        ]),
        isNull,
      );
      expect(activeLobbyOf([_group(id: 'a')])?.id, 'a');
      expect(
        activeLobbyOf([
          _group(id: 'inv', myState: 'invited', organizer: false),
        ])?.id,
        'inv',
      );
    });
  });

  testWidgets('home card says where the group is and how many came', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeLobbyCard(group: _group())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Собираетесь у костра'), findsOneWidget);
    expect(find.text('Классика Южного берега'), findsOneWidget);
    expect(find.text('2 из 6'), findsOneWidget);
    expect(find.text('Вернуться в лобби'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an invitation on the home card names who calls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeLobbyCard(
            group: _group(myState: 'invited', organizer: false),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Анна зовёт вас'), findsOneWidget);
    expect(find.text('Посмотреть приглашение'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('«Мои группы» lists live groups first, then past ones', (
    tester,
  ) async {
    final groups = [
      _group(id: 'old', status: 'settled', route: 'Ай-Петри'),
      _group(id: 'now'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: companionGroupsSlivers(AsyncData(groups)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Прошедшие'), findsOneWidget);
    expect(find.textContaining('Маршрут пройден'), findsOneWidget);
    final live = tester.getTopLeft(find.text('Классика Южного берега')).dy;
    final past = tester.getTopLeft(find.text('Ай-Петри')).dy;
    expect(live, lessThan(past));
  });

  testWidgets('«Мои группы» is never a dead end when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: companionGroupsSlivers(
              const AsyncData(<CompanionGroup>[]),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('«Пройти вместе»'), findsOneWidget);
  });

  testWidgets('already in a group: the notice offers to go to its lobby', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          companionsRepositoryProvider.overrideWithValue(
            _Repo([_group(id: 'live')]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showCompanionError(
                  context,
                  ref,
                  const RejectedFailure(
                    'Вы уже в другой группе. Сначала выйдите из неё.',
                    companionBusyCode,
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Вы уже в другой группе. Сначала выйдите из неё.'),
      findsOneWidget,
    );
    expect(find.text('Перейти в активное лобби'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  test('the demo repository refuses a second live group like the server', () {
    final repo = MockCompanionsRepository(meId: 'me', meName: 'Я');
    expect(
      () async {
        await repo.create('r1');
        await repo.create('r2');
      }(),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', companionBusyCode),
      ),
    );
  });
}
