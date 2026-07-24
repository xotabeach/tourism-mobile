import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

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
    await tester.pumpAndSettle();

    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsOneWidget);
    final otpFields = find.byType(TextField);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(otpFields.at(i), '${i + 1}');
    }
    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.tap(find.byType(CheckboxListTile).at(1));
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
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Места Крыма'), findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsOneWidget);
  });

  testWidgets('routes tab shows editorial catalog from mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.workspaces_outline));
    await tester.pumpAndSettle();

    expect(find.text('Классика Южного берега'), findsOneWidget);

    await tester.tap(find.text('Классика Южного берега'));
    await tester.pumpAndSettle();

    expect(find.text('КрымТрип редакция'), findsOneWidget);
  });
}
