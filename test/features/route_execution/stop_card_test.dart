import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/stop_card_sheet.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_stop_list.dart';

const _located = RouteExecutionStop(
  id: 's1',
  position: 2,
  placeName: 'Ротонда',
  isOptional: false,
  lat: 44.67,
  lng: 34.41,
);

const _unlocated = RouteExecutionStop(
  id: 's2',
  position: 3,
  placeName: 'Без координат',
  isOptional: false,
);

Future<void> _openCard(WidgetTester tester, RouteExecutionStop stop) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStopCardSheet(context, stop: stop),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the card of a stop offers the way to it', (tester) async {
    await _openCard(tester, _located);

    expect(find.text('Ротонда'), findsOneWidget);
    expect(find.text('Проложить до точки'), findsOneWidget);
    // No place behind the stop: nothing to load and no page to open.
    expect(find.text('Страница места'), findsNothing);
    expect(find.text('Загружаем описание…'), findsNothing);
  });

  testWidgets('a stop without coordinates has no way to lead to', (
    tester,
  ) async {
    await _openCard(tester, _unlocated);

    expect(find.text('Без координат'), findsOneWidget);
    expect(find.text('Проложить до точки'), findsNothing);
  });

  testWidgets('the next stop has both links and they fit a narrow phone', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(280, 600);
    addTearDown(tester.view.reset);
    var navigated = 0;
    var skipped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExecutionNextStopActions(
            placeName: 'Ротонда',
            onNavigate: () => navigated++,
            onSkip: () => skipped++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Проложить до точки'));
    await tester.tap(find.text('Пропустить точку'));
    expect((navigated, skipped), (1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without coordinates only the skip link is left', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExecutionNextStopActions(placeName: 'Ротонда', onSkip: () {}),
        ),
      ),
    );

    expect(find.text('Проложить до точки'), findsNothing);
    expect(find.text('Пропустить точку'), findsOneWidget);
  });
}
