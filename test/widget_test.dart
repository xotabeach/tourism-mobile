import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';

void main() {
  testWidgets('shows platform foundation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TourismApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Crimea Travel Platform'), findsOneWidget);
    expect(find.textContaining('http://localhost:8000'), findsOneWidget);
  });
}
