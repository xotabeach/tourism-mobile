import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('the red delete plate is hidden at rest and never reaches under '
      'the card while swiping', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1200);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(home: SettingsNotificationsInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final plate = find.byKey(const ValueKey('inbox-delete-plate'));
    expect(plate, findsNothing);

    final card = find.byKey(const ValueKey('inbox-n1'));
    final cardRect = tester.getRect(card);
    final gesture = await tester.startGesture(cardRect.center);
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    expect(plate, findsOneWidget);
    final plateRect = tester.getRect(plate);
    final tile = find.descendant(of: card, matching: find.byType(Material));
    final movedCard = tester.getRect(tile.first);
    // Right edge flush with where the card was, left edge clear of the card
    // (a gap, no red behind the card's rounded corners), same height.
    expect(plateRect.right, moreOrLessEquals(cardRect.right, epsilon: 0.5));
    expect(plateRect.left, greaterThan(movedCard.right));
    expect(plateRect.height, moreOrLessEquals(cardRect.height, epsilon: 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
