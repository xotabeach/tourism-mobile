import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';

const _testConfig = AppConfig(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  useMockData: true,
);

List<Override> _testOverrides({bool onboardingCompleted = false}) {
  return [
    appConfigProvider.overrideWithValue(_testConfig),
    if (onboardingCompleted)
      sessionProvider.overrideWith(
        (ref) => SessionController(
          const SessionState(onboardingCompleted: true, displayName: 'Никита'),
        ),
      ),
  ];
}

ProviderScope appWithCompletedOnboarding() {
  return ProviderScope(
    overrides: _testOverrides(onboardingCompleted: true),
    child: const TourismApp(),
  );
}

void main() {
  testWidgets('welcome leads into mock auth and home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _testOverrides(), child: const TourismApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ИДЕАЛЬНЫЙ'), findsOneWidget);
    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ПУТНИК'), findsOneWidget);
    final identityFields = find.byType(TextFormField);
    await tester.enterText(identityFields.at(0), 'Никита');
    await tester.enterText(identityFields.at(1), '9991234567');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(identityFields.at(1)).controller?.text,
      '+7 999 123-45-67',
    );
    await tester.tap(find.text('Продолжить'));
    // The OTP screen shows a perpetually blinking caret, so settle the route
    // transition with bounded pumps instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.textContaining('политикой конфиденциальности'));
    await tester.tap(find.textContaining('персональных данных'));
    await tester.pump();
    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    expect(find.textContaining('ПОСТРОЙ'), findsOneWidget);
  });

  testWidgets('shows home and opens places catalog from mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Карта'));
    await tester.pumpAndSettle();

    expect(find.text('Места Крыма'), findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsOneWidget);
  });

  testWidgets('routes tab shows swipe deck from mock data', (
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Маршруты'));
    await tester.pumpAndSettle();

    expect(find.text('Хорошо'), findsOneWidget);
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Хорошо'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(RouteSwipeDeck), findsOneWidget);
    expect(find.text('Классика Южного берега'), findsWidgets);

    await tester.tap(find.text('Классика Южного берега').first);
    await tester.pumpAndSettle();

    expect(find.text('КрымТрип редакция'), findsWidgets);
  });
}
