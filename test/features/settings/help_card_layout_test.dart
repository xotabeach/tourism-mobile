import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

import '../../support/test_overrides.dart';

void main() {
  for (final width in [375.0, 440.0]) {
    testWidgets('help card keeps one grid at $width dp', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(width, 900);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: testSessionOverrides(onboardingCompleted: true),
          child: const MaterialApp(
            home: Scaffold(body: SettingsSupportScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byKey(const ValueKey('support-help-card')),
      );
      final field = tester.getRect(find.byType(TextField));
      final find1 = tester.getRect(
        find.widgetWithText(FilledButton, 'Найти инструкцию'),
      );
      final operator = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Написать оператору'),
      );
      final hairlines = find.byType(SettingsHairline);
      final inCard = tester.getRect(hairlines.first);
      final underCard = tester.getRect(hairlines.at(1));

      // Field, buttons and the line in the card share the card's inner edges.
      expect(field.left - card.left, 16);
      expect(card.right - field.right, 16);
      for (final r in [find1, operator, inCard]) {
        expect(r.left, field.left);
        expect(r.right, field.right);
      }
      // Even gaps: field to button equals button to button.
      expect(find1.top - field.bottom, operator.top - find1.bottom);
      // The line under the card spans the card itself.
      expect(underCard.left, card.left);
      expect(underCard.right, card.right);
    });
  }
}
