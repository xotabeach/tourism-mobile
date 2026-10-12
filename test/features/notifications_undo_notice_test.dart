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
  testWidgets('a deleted card turns into «Удалить уведомление?» in its place, '
      'and its cross brings the notification back', (tester) async {
    await _pumpInbox(tester);
    expect(find.text('Ответ поддержки'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-delete-n1')));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Удалить уведомление?'), findsOneWidget);
    expect(find.text('Автоматическое удаление через 5с'), findsOneWidget);
    expect(find.text('Ответ поддержки'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Автоматическое удаление через 3с'), findsOneWidget);

    await tester.tap(find.byTooltip('Не удалять'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить уведомление?'), findsNothing);
    expect(find.text('Ответ поддержки'), findsOneWidget);
  });

  testWidgets('after the undo window the row is gone for good', (tester) async {
    await _pumpInbox(tester);
    await tester.tap(find.byKey(const ValueKey('inbox-delete-n1')));
    await tester.pump();
    expect(find.text('Удалить уведомление?'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Удалить уведомление?'), findsNothing);
    expect(find.text('Ответ поддержки'), findsNothing);
  });

  testWidgets('the clear dialog is the DESIGN-8 one', (tester) async {
    await _pumpInbox(tester);
    await tester.tap(find.text('Очистить все'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить все уведомления?'), findsOneWidget);
    expect(find.text('Всё равно удалить'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить все уведомления?'), findsNothing);
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
