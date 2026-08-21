import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
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
              {'id': 'pace_calm', 'label': 'Хочу спокойно'},
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

  testWidgets('RouteAiChatView shows confirmed summary and dynamic chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteAiChatView(
            header: const SizedBox.shrink(),
            px: (value) => value,
            messages: const [
              RouteChatMessage(
                fromAgent: true,
                text: 'На машине или транспорте?',
                time: '13:41',
                actions: [
                  {'id': 'transport_car', 'label': 'На машине'},
                  {'id': 'transport_public', 'label': 'Общественный транспорт'},
                ],
              ),
            ],
            scrollController: ScrollController(),
            composerController: TextEditingController(),
            composerFocus: FocusNode(),
            typing: false,
            canSend: false,
            onChanged: (_) {},
            onSend: () {},
            bottomInset: 0,
            confirmedSummary: 'Учли: Ялта · горы',
            onChatAction: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('Учли: Ялта · горы'), findsOneWidget);
    expect(find.text('На машине'), findsOneWidget);
    expect(find.text('Общественный транспорт'), findsOneWidget);
    expect(find.text('Хочу спокойно'), findsNothing);
  });
}
