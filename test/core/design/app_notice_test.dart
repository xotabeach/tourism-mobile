import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';

Widget _host(void Function(BuildContext context) onTap) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onTap(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the message and auto-dismisses without leaking a timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppNotice(
          context,
          'Готово',
          duration: const Duration(seconds: 2),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(find.text('Готово'), findsOneWidget);
    // The app's own notice, not Material's bottom slab.
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Готово'), findsNothing);
  });

  testWidgets('keeps an undo action tappable', (tester) async {
    var undone = false;
    await tester.pumpWidget(
      _host(
        (context) => showAppNotice(
          context,
          'Удалено',
          actionLabel: 'Вернуть',
          onAction: () => undone = true,
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть'));
    await tester.pump();

    expect(undone, isTrue);
    expect(find.text('Удалено'), findsNothing);
  });

  testWidgets('a second notice replaces the first', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(_host((context) => hostContext = context));
    await tester.tap(find.text('trigger'));
    await tester.pump();

    showAppNotice(hostContext, 'Первое');
    await tester.pump();
    showAppNotice(hostContext, 'Второе');
    await tester.pump();

    expect(find.text('Первое'), findsNothing);
    expect(find.text('Второе'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
