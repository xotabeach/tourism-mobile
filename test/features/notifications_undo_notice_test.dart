import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';

import '../support/test_overrides.dart';

Future<void> _pumpInbox(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1400);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsNotificationsInboxScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deleting shows the app notice with «Отменить», which brings '
      'the notification back', (tester) async {
    await _pumpInbox(tester);
    expect(find.text('Ответ поддержки'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-delete-n1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Уведомление удалено'), findsOneWidget);
    expect(find.text('Ответ поддержки'), findsNothing);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Уведомление удалено'), findsNothing);
    expect(find.text('Ответ поддержки'), findsOneWidget);
  });

  testWidgets('leaving the screen takes the undo notice with it', (
    tester,
  ) async {
    await _pumpInbox(tester);
    await tester.tap(find.byKey(const ValueKey('inbox-delete-n1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Уведомление удалено'), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(SettingsNotificationsInboxScreen)),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('Уведомление удалено'), findsNothing);
    expect(find.text('Отменить'), findsNothing);
  });

  test('the app has no stock SnackBar left', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            RegExp(
              r'\bSnackBar\(|showSnackBar\(',
            ).hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
