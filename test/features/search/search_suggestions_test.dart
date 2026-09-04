import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';

import '../../support/test_overrides.dart';

/// Подсказки в поиске: короткая строка «название — тип» с переходом сразу в
/// объект. До них человек листал карусели карточек, чтобы найти знакомое имя.
Future<void> _pump(WidgetTester tester, String query) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1600);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InPlaceSearchBody(query: query),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggestions appear for a query and name the kind', (
    tester,
  ) async {
    await _pump(tester, 'Ай');

    expect(find.text('Подсказки:'), findsOneWidget);
    // Тип подписан справа — по нему видно, куда ведёт строка.
    expect(
      find.byType(InPlaceSearchBody),
      findsOneWidget,
      reason: 'экран поиска должен построиться',
    );
    final kinds = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where(
          (value) =>
              value == 'Локация' ||
              value == 'Маршрут' ||
              value == 'Блог',
        );
    expect(kinds, isNotEmpty);
  });

  testWidgets('an empty query shows no suggestions block', (tester) async {
    await _pump(tester, '');

    expect(find.text('Подсказки:'), findsNothing);
  });
}
