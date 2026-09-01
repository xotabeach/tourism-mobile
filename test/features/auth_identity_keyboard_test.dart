import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/auth/presentation/auth_identity_screen.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('name field asks for a text keyboard, not the phone one', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(),
        child: const MaterialApp(home: AuthIdentityScreen()),
      ),
    );
    await tester.pump();

    // A number nobody is registered under: the mock answers
    // registrationRequired, which is what reveals the name field.
    await tester.enterText(
      find.byKey(const ValueKey('auth-phone-field')),
      '+7 912 345-67-89',
    );
    await tester.pump();

    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final nameField = find.byKey(const ValueKey('auth-name-field'));
    expect(nameField, findsOneWidget, reason: 'registration step should appear');

    // The regression: the name field used to reuse the phone field's element
    // (same type, same index, no keys), inheriting its live text input
    // connection — so the numeric keyboard stayed up while the user was
    // being asked for their name.
    final nameEditable = tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    expect(nameEditable.keyboardType, TextInputType.name);
    expect(nameEditable.focusNode.hasFocus, isTrue);

    final phoneEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-phone-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(phoneEditable.keyboardType, TextInputType.phone);

    // Both fields must be distinct elements, or the platform keyboard
    // configuration of one leaks into the other.
    expect(nameEditable, isNot(same(phoneEditable)));
  });
}
