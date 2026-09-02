import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/domain/crimea_cities.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_notifier.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_interactive_controls.dart';

RouteChatSelectData _cityData({String? value}) {
  return RouteChatSelectData(
    id: 'city',
    label: 'Стартовый город',
    placeholder: 'Город',
    value: value,
    options: [
      for (final city in crimeaCities)
        SelectOptionItem(value: city, label: city),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required void Function(String) onSelected,
  String? value,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 241,
            child: ChatSelectControl(
              px: (v) => v,
              data: _cityData(value: value),
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts collapsed, showing the placeholder', (tester) async {
    await _pump(tester, onSelected: (_) {});

    expect(find.text('Город'), findsOneWidget);
    expect(find.text('Симферополь'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('tapping the header reveals the options', (tester) async {
    await _pump(tester, onSelected: (_) {});

    await tester.tap(find.byKey(const ValueKey('chat-select-header')));
    await tester.pumpAndSettle();

    expect(find.text('Симферополь'), findsOneWidget);
    expect(find.text('Севастополь'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
  });

  testWidgets('picking a city reports its value and collapses the list', (
    tester,
  ) async {
    String? picked;
    await _pump(tester, onSelected: (value) => picked = value);

    await tester.tap(find.byKey(const ValueKey('chat-select-header')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ялта'));
    await tester.pumpAndSettle();

    expect(picked, 'Ялта');
    // Collapsed again, and the header now carries the choice.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.text('Ялта'), findsOneWidget);
    expect(find.text('Город'), findsNothing);
  });

  testWidgets('an already-chosen value shows instead of the placeholder', (
    tester,
  ) async {
    await _pump(tester, onSelected: (_) {}, value: 'Алушта');

    expect(find.text('Алушта'), findsOneWidget);
    expect(find.text('Город'), findsNothing);
  });

  test('selectsFromBlocks maps a select block, skipping an empty one', () {
    final blocks = <RouteChatBlock>[
      const SelectBlock(
        id: 'city',
        label: 'Стартовый город',
        placeholder: 'Город',
        options: [SelectOptionItem(value: 'Ялта', label: 'Ялта')],
      ),
      // No options — nothing to choose from, so it must not reach the UI.
      const SelectBlock(id: 'empty', label: 'Пусто', options: []),
    ];

    final selects = selectsFromBlocks(blocks);

    expect(selects, hasLength(1));
    expect(selects.single.id, 'city');
    expect(selects.single.placeholder, 'Город');
    expect(selects.single.options.single.value, 'Ялта');
  });

  test('the select block parses from the agent payload', () {
    final block =
        RouteChatBlock.fromJson({
              'type': 'select',
              'id': 'city',
              'label': 'Стартовый город',
              'placeholder': 'Город',
              'options': [
                {'value': 'Ялта', 'label': 'Ялта'},
                {'value': 'Судак'},
                // Malformed entries are dropped rather than rendered blank.
                {'label': 'без значения'},
                'мусор',
              ],
            })
            as SelectBlock;

    expect(block.id, 'city');
    expect(block.options.map((o) => o.value), ['Ялта', 'Судак']);
    // A missing label falls back to the value, so nothing renders empty.
    expect(block.options.last.label, 'Судак');
  });
}
