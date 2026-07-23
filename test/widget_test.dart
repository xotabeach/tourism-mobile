import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';

void main() {
  testWidgets('shows home and opens places catalog from mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TourismApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Crimea Travel Platform'), findsOneWidget);
    expect(find.text('Каталог мест'), findsOneWidget);

    await tester.tap(find.text('Каталог мест'));
    await tester.pumpAndSettle();

    expect(find.text('Места Крыма'), findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsOneWidget);
  });

  testWidgets('routes tab shows editorial catalog from mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TourismApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Маршруты'));
    await tester.pumpAndSettle();

    expect(find.text('Маршруты Крыма'), findsOneWidget);
    expect(find.text('Классика Южного берега'), findsOneWidget);

    await tester.tap(find.text('Классика Южного берега'));
    await tester.pumpAndSettle();

    expect(find.text('Карточка маршрута'), findsOneWidget);
    expect(find.text('Воронцовский дворец'), findsOneWidget);
  });
}
