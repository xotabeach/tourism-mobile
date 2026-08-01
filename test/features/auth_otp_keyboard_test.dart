import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/auth/presentation/auth_otp_screen.dart';

void main() {
  testWidgets('reopens keyboard when an OTP cell is tapped after resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthOtpScreen())),
    );
    // Caret blinks forever — avoid pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final editable = find.byType(EditableText);
    expect(editable, findsOneWidget);
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    // Valid lifecycle path used by iOS when backgrounding the app.
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Пустое поле кода').first);
    await tester.pump();
    await tester.pump();

    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
  });
}
