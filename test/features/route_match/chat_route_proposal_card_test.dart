import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
            title: 'Ялта · море и виды',
            stopsCount: 4,
            durationMinutes: 280,
            onCreate: () => created = true,
            onSaveDraft: () {},
            onRefine: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ялта · море и виды'), findsOneWidget);
    expect(find.textContaining('4 точек'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
    expect(find.text('В черновик'), findsOneWidget);
    expect(find.text('Уточнить'), findsOneWidget);
    await tester.tap(find.text('Создать'));
    expect(created, isTrue);
  });
}
