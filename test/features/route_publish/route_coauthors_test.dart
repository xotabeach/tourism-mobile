import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';
import 'package:tourism_mobile/features/route_publish/data/route_coauthors_repository.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_coauthors_section.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/coauthor_avatars.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../../support/test_overrides.dart';

// FRONTEND-65: co-authors in the app, as DESIGN-19 draws them (spec 11c D7).

class _Coauthor extends MockRouteCoauthorsRepository {
  _Coauthor();

  @override
  Future<RouteCoauthorsInfo> load(String routeId) async =>
      const RouteCoauthorsInfo(
        isOwner: false,
        ownerUserId: 'anna',
        ownerConsented: true,
        coauthors: [RouteCoauthor(userId: 'mock-user', displayName: 'Никита')],
      );
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  test('a route reads its co-authors and names them all', () {
    final route = RouteSummary.fromJson({
      'id': 'r1',
      'name': 'Гора Чок-Сары-Кая',
      'slug': 'chok',
      'short_description': null,
      'stops_count': 3,
      'author_label': 'Никита',
      'coauthors': [
        {'user_id': 'a', 'display_name': 'Андрей', 'consented': true},
      ],
    });
    expect(route.coauthors.single.displayName, 'Андрей');
    expect(route.coauthors.single.consented, isTrue);
    expect(CoauthorAvatars.names('Никита', ['Андрей']), 'Никита и Андрей');
    expect(
      CoauthorAvatars.names('Никита', ['Андрей', 'Оля']),
      'Никита, Андрей и Оля',
    );
  });

  testWidgets('the card says «Никита и Андрей», «Маршрут в соавторстве»', (
    tester,
  ) async {
    const route = RouteSummary(
      id: 'r1',
      name: 'Гора Чок-Сары-Кая',
      slug: 'chok',
      shortDescription: null,
      stopsCount: 3,
      authorLabel: 'Никита',
      ownerUserId: 'nikita',
      coauthors: [RouteCoauthor(userId: 'andrey', displayName: 'Андрей')],
    );
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 361,
          child: RouteHeroCard(route: route, interactive: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Никита и Андрей'), findsOneWidget);
    expect(find.text('Маршрут в соавторстве'), findsOneWidget);
    expect(find.byType(CoauthorAvatars), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the owner picks co-authors and sees the mutual consent', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1200);
    addTearDown(tester.view.reset);
    var chosen = <String>{};
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => RouteCoauthorsSection(
            u: (v) => v,
            routeId: 'r1',
            selected: chosen,
            onChanged: (ids) => setState(() => chosen = ids),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Соавторство:'), findsOneWidget);
    expect(find.text('Обоюдное согласие'), findsNothing);

    await tester.tap(find.text('Добавить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Андрей'));
    await tester.pump();
    expect(chosen, {'friend-1'});
    expect(find.text('Обоюдное согласие'), findsOneWidget);
    expect(find.text('Никита и Андрей'), findsOneWidget);

    // The search narrows the people.
    await tester.enterText(
      find.byKey(const ValueKey('coauthor-search')),
      'мар',
    );
    await tester.pump();
    expect(find.text('Марина'), findsOneWidget);
    expect(find.text('Глеб'), findsNothing);
  });

  testWidgets('a co-author sees the offer and may decline', (tester) async {
    var left = false;
    await tester.pumpWidget(
      _host(
        RouteCoauthorsSection(
          u: (v) => v,
          routeId: 'r1',
          selected: null,
          onChanged: (_) {},
          onLeft: () => left = true,
        ),
        overrides: [
          routeCoauthorsRepositoryProvider.overrideWithValue(_Coauthor()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Вас позвали в соавторы'), findsOneWidget);
    expect(find.text('Добавить'), findsNothing);
    await tester.tap(find.text('Отказаться от соавторства'));
    await tester.pump();
    expect(left, isTrue);
  });
}
