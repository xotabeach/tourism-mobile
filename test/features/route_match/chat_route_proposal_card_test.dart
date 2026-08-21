import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_route_proposal_card.dart';

void main() {
  testWidgets('ChatRouteProposalCard shows actions without HTML', (
    tester,
  ) async {
    var created = false;
    await tester.pumpWidget(
      MaterialApp(
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
    expect(find.text('В черновик'), findsOneWidget);
    expect(find.text('Уточнить'), findsOneWidget);
    await tester.tap(find.text('Пройти маршрут'));
    expect(created, isTrue);
  });

  testWidgets('ChatRouteProposalCard renders rating/tags/params from card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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
    expect(find.text('8.6 км'), findsWidgets);
    expect(find.text('Бахчисарай'), findsWidgets);
    expect(find.text('Горы'), findsOneWidget);
    expect(find.text('С детьми'), findsOneWidget);
    expect(find.text('2 500 ₽'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
  });

  testWidgets(
    'ChatRouteProposalCard assembled variant shows locations and map',
    (tester) async {
      var viewedMap = false;
      await tester.pumpWidget(
        MaterialApp(
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
            ),
          ),
        ),
      );

      expect(find.text('Локации собранного маршрута:'), findsOneWidget);
      expect(find.text('Ласточкино гнездо'), findsOneWidget);
      expect(find.text('Посмотреть на карте'), findsOneWidget);
      await tester.tap(find.text('Посмотреть на карте'));
      expect(viewedMap, isTrue);
    },
  );
}
