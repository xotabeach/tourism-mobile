import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('OTP screen can go back to phone entry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9990000000');
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Назад'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ПО НОМЕРУ'), findsOneWidget);
    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsNothing);
  });

  testWidgets('welcome shows session avatar when authenticated', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Открыть приложение'), findsOneWidget);
    expect(find.bySemanticsLabel('Открыть профиль'), findsNothing);
  });
}
