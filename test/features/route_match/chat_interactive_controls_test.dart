import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_interactive_controls.dart';

double identityPx(double value) => value;

void main() {
  testWidgets('ChatSliderControl shows a live value bubble and commits', (
    tester,
  ) async {
    double? committed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ChatSliderControl(
              px: identityPx,
              data: const RouteChatSliderData(
                id: 'budget_amount',
                label: 'Бюджет на день',
                minValue: 0,
                maxValue: 20000,
                step: 500,
                value: 3000,
                unit: '₽',
              ),
              onCommit: (id, value) => committed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('₽'), findsWidgets);
    // Drag the thumb far right and release to commit a value.
    await tester.drag(
      find.byType(Slider),
      const Offset(120, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(committed, isNotNull);
    expect(committed!, greaterThan(3000));
  });

  testWidgets('ChatToggleControl flips via tap', (tester) async {
    bool? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ChatToggleControl(
              px: identityPx,
              data: const RouteChatToggleData(
                id: 'with_children',
                label: 'Едем с детьми',
                value: false,
              ),
              onChanged: (id, v) => value = v,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Едем с детьми'), findsOneWidget);
    await tester.tap(find.text('Едем с детьми'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('Ai chat typing indicator renders animated dots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteAiChatView(
            header: const SizedBox(height: 80),
            px: identityPx,
            messages: const <RouteChatMessage>[],
            scrollController: ScrollController(),
            composerController: TextEditingController(),
            composerFocus: FocusNode(),
            typing: true,
            canSend: false,
            onChanged: (_) {},
            onSend: () {},
            bottomInset: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    // Animated dots + short label, no enclosing bubble anymore.
    expect(find.text('Тревел Агент печатает…'), findsNothing);
    expect(find.textContaining('думает'), findsOneWidget);
  });
}
