import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_route_proposal_card.dart';

import '../../support/test_overrides.dart';

Widget _app({required Widget home}) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(testAppConfig)],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('ChatRouteProposalCard shows actions without HTML', (
    tester,
  ) async {
    var created = false;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: ChatRouteProposalCard(
            card: const RouteProposalCardData(
              proposalId: 'p1',
              title: 'Ялта · море и виды',
              stopsCount: 4,
              durationMinutes: 280,
            ),
            onCreate: () => created = true,
            onSaveDraft: () {},
            onRefine: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ялта · море и виды'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.text('Пройти маршрут'), findsOneWidget);
    expect(find.text('Сохранить маршрут в черновик'), findsOneWidget);
    expect(find.text('Указать агенту на ошибку'), findsOneWidget);
    await tester.tap(find.text('Пройти маршрут'));
    expect(created, isTrue);
  });

  testWidgets('ChatRouteProposalCard renders rating/tags/params from card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: const Scaffold(
          body: ChatRouteProposalCard(
            card: RouteProposalCardData(
              proposalId: 'p2',
              title: 'Гора Чок-Сары-Кая',
              stopsCount: 3,
              durationMinutes: 180,
              coverUrl: 'https://example.com/chok.jpg',
              rating: 4.9,
              distanceKm: 8.6,
              localityLabel: 'Бахчисарай',
              tags: ['Горы', 'С детьми', 'Пешком'],
              budgetLabel: '2 500 ₽',
              difficultyLabel: '3/5',
            ),
          ),
        ),
      ),
    );

    expect(find.text('4.9'), findsOneWidget);
    expect(find.textContaining('8.6 км'), findsWidgets);
    expect(find.textContaining('Бахчисарай'), findsWidgets);
    expect(find.text('Горы'), findsOneWidget);
    expect(find.text('С детьми'), findsOneWidget);
    // Param rows render as one rich "label value" line (design screen 2).
    expect(find.textContaining('2 500 ₽'), findsOneWidget);
    expect(find.textContaining('3/5'), findsOneWidget);
  });

  testWidgets(
    'ChatRouteProposalCard assembled variant shows locations and map',
    (tester) async {
      var viewedMap = false;
      await tester.pumpWidget(
        _app(
          home: SingleChildScrollView(
            child: ChatRouteProposalCard(
              card: const RouteProposalCardData(
                proposalId: 'p3',
                title: 'Крым · собранный маршрут',
                stopsCount: 4,
                durationMinutes: 300,
                cardVariant: RouteProposalCardVariant.assembled,
                galleryUrls: ['https://example.com/a.jpg'],
                startLabel: 'Симферополь',
                finishLabel: 'Ялта',
                locations: [
                  ProposalLocationItem(
                    id: 'loc-1',
                    title: 'Ласточкино гнездо',
                    index: 1,
                  ),
                ],
                tags: ['Горы'],
              ),
              onViewMap: () => viewedMap = true,
              onCreate: () {},
              onSaveDraft: () {},
            ),
          ),
        ),
      );

      // Design-spec screen 3: labeled start/finish sections, no separate
      // route title under the gallery.
      expect(find.text('Точка старта:'), findsOneWidget);
      expect(find.text('Точка финиша:'), findsOneWidget);
      expect(find.text('Крым · собранный маршрут'), findsNothing);
      expect(find.text('Локации собранного маршрута:'), findsOneWidget);
      expect(find.text('Ласточкино гнездо'), findsOneWidget);
      expect(find.text('Посмотреть на карте'), findsOneWidget);
      await tester.ensureVisible(find.text('Посмотреть на карте'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Посмотреть на карте'));
      expect(viewedMap, isTrue);

      // The design export renders every outlined button in this card at one
      // visual weight — "Посмотреть на карте" must match the secondary
      // action buttons below it (height/radius/border color), not the
      // smaller/gray style it used to have.
      final mapButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Посмотреть на карте'),
          matching: find.byType(OutlinedButton),
        ),
      );
      final draftButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Сохранить маршрут в черновик'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(mapButton.style?.minimumSize, draftButton.style?.minimumSize);
      expect(mapButton.style?.side, draftButton.style?.side);
      expect(mapButton.style?.shape, draftButton.style?.shape);
    },
  );
}
