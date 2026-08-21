import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_action_chips.dart';

void main() {
  testWidgets('ChatActionChips invokes onAction without HTML', (tester) async {
    String? tappedId;
    String? tappedLabel;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatActionChips(
            px: (value) => value,
            actions: const [
              {'id': 'want_generate', 'label': 'Подбери маршрут'},
              {'id': 'say_mood_calm', 'label': 'Хочу спокойно'},
            ],
            onAction: (id, label) {
              tappedId = id;
              tappedLabel = label;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Подбери маршрут'));
    await tester.pump();

    expect(tappedId, 'want_generate');
    expect(tappedLabel, 'Подбери маршрут');
    expect(find.byType(HtmlElementView), findsNothing);
  });
}
