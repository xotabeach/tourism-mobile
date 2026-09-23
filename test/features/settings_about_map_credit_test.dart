import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/presentation/settings_screen.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('«О приложении» credits OpenStreetMap and OpenMapTiles', (
    tester,
  ) async {
    // ODbL and the OpenMapTiles schema need a visible credit (spec 12, D16).
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(home: SettingsAboutScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Карты и маршруты'), findsOneWidget);
    expect(find.textContaining('© участники OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('© OpenMapTiles'), findsOneWidget);
  });
}
