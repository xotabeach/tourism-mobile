import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
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

  testWidgets('ChatActionChips stack layout renders full-width buttons', (
    tester,
  ) async {
    String? tappedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatActionChips(
            px: (value) => value,
            layout: ChatActionsLayout.stack,
            actions: const [
              {'id': 'pace_calm', 'label': 'Спокойный маршрут'},
              {'id': 'interest_sea', 'label': 'Путешествие к морю'},
            ],
            onAction: (id, _) => tappedId = id,
          ),
        ),
      ),
    );

    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Спокойный маршрут'), findsOneWidget);
    await tester.tap(find.text('Путешествие к морю'));
    await tester.pump();
    expect(tappedId, 'interest_sea');
  });

  testWidgets('ChatActionChips sheet layout opens a picker with all options', (
    tester,
  ) async {
    String? tappedId;
    String? tappedLabel;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatActionChips(
            px: (value) => value,
            layout: ChatActionsLayout.sheet,
            sheetTitle: 'Выбрать город',
            actions: const [
              {'id': 'city_yalta', 'label': 'Ялта'},
              {'id': 'city_sevastopol', 'label': 'Севастополь'},
            ],
            onAction: (id, label) {
              tappedId = id;
              tappedLabel = label;
            },
          ),
        ),
      ),
    );

    expect(find.text('Ялта'), findsNothing);
    await tester.tap(find.text('Выбрать город'));
    await tester.pumpAndSettle();

    expect(find.text('Ялта'), findsOneWidget);
    expect(find.text('Севастополь'), findsOneWidget);
    await tester.tap(find.text('Севастополь'));
    await tester.pumpAndSettle();

    expect(tappedId, 'city_sevastopol');
    expect(tappedLabel, 'Севастополь');
  });

  testWidgets('RouteAiChatView shows dynamic chips', (tester) async {
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
            onChatAction: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Учли:'), findsNothing);
    expect(find.text('На машине'), findsOneWidget);
    expect(find.text('Общественный транспорт'), findsOneWidget);
    expect(find.text('Хочу спокойно'), findsNothing);
  });
}
