import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/mark_confirm_dialog.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_summary_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<bool?> _open(
  WidgetTester tester,
  Future<bool> Function(BuildContext) show,
) async {
  bool? result;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await show(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

RouteExecution _finished({
  RoutePointsStatus status = RoutePointsStatus.awarded,
  String? reason,
  int awarded = 0,
  int held = 0,
  RouteExecutionAntiFraud? antifraud,
}) => RouteExecution(
  id: 'e',
  routeName: 'Южный берег',
  status: RouteExecutionStatus.completed,
  startedAt: DateTime.utc(2026, 9, 20, 9),
  completedAt: DateTime.utc(2026, 9, 20, 12),
  totalStops: 3,
  completedStops: 3,
  requiredStops: 3,
  completedRequiredStops: 3,
  stops: const [],
  pointsStatus: status,
  pointsReason: reason,
  awardedPoints: awarded,
  heldPoints: held,
  antifraud: antifraud,
);

void main() {
  group('mark confirmation dialog', () {
    testWidgets('"not there yet" wording and the confirm button', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMarkConfirmDialog(
                context,
                notThereYet: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Кажется, вы ещё не дошли до этой точки'),
        findsOneWidget,
      );
      expect(find.text('Точно отметить?'), findsOneWidget);
      await tester.tap(find.text('Всё равно отметить'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancelling confirms nothing', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMarkConfirmDialog(
                context,
                notThereYet: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Быстрее, чем обычно'), findsOneWidget);
      await tester.tap(find.text('Отменить отметку'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('dismissing by tapping outside counts as cancel', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMarkConfirmDialog(
                context,
                notThereYet: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('location explanation dialog', () {
    testWidgets('"Разрешить" returns true', (tester) async {
      await _open(tester, showLocationExplanationDialog);
      expect(find.text('Разрешить геолокацию?'), findsOneWidget);
      expect(find.textContaining('необязательно'), findsOneWidget);
      await tester.tap(find.text('Разрешить'));
      await tester.pumpAndSettle();
      expect(find.text('Разрешить геолокацию?'), findsNothing);
    });

    testWidgets('"Не сейчас" returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showLocationExplanationDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Не сейчас'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('summary screen points wording', () {
    testWidgets('an ordinary completion keeps the regular badge only', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RouteExecutionSummaryScreen(
              execution: _finished(awarded: 50),
            ),
          ),
        ),
      );
      expect(find.text('+50 ТП'), findsOneWidget);
      // The design's layout: title, three stat tiles, the way back.
      expect(find.text('Маршрут пройден!'), findsOneWidget);
      expect(find.text('Статистика:'), findsOneWidget);
      expect(find.bySemanticsLabel('Посещено: 3 места'), findsOneWidget);
      expect(find.bySemanticsLabel('Время в пути: 180 мин.'), findsOneWidget);
      expect(find.bySemanticsLabel('На страницу маршрута'), findsOneWidget);
      expect(find.textContaining('проверк'), findsNothing);
      expect(find.textContaining('лимит'), findsNothing);
    });

    testWidgets('held points show the review wording', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RouteExecutionSummaryScreen(
              execution: _finished(status: RoutePointsStatus.held, held: 40),
            ),
          ),
        ),
      );
      expect(find.text('Очки на проверке (40)'), findsOneWidget);
      expect(find.textContaining('Команда проверит'), findsOneWidget);
    });

    testWidgets('cooldown quotes the server limit', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RouteExecutionSummaryScreen(
              execution: _finished(
                reason: 'route_cooldown',
                antifraud: const RouteExecutionAntiFraud(
                  gpsToleranceMeters: 150,
                  gpsMinAccuracyMeters: 100,
                  routeCooldownDays: 14,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Очки не начислены'), findsOneWidget);
      expect(find.textContaining('14 дней'), findsOneWidget);
    });

    testWidgets(
      'a partial daily-cap award keeps the +N badge and adds the note',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: RouteExecutionSummaryScreen(
                execution: _finished(
                  reason: 'daily_cap',
                  awarded: 20,
                  antifraud: const RouteExecutionAntiFraud(
                    gpsToleranceMeters: 150,
                    gpsMinAccuracyMeters: 100,
                    dailyPointsCap: 600,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('+20 ТП'), findsOneWidget);
        expect(find.textContaining('лимит очков (600)'), findsOneWidget);
      },
    );
  });

  group('start button while blocked', () {
    testWidgets('looks unavailable but still re-checks on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            height: 80,
            child: RouteStartButton(
              onPressed: () => taps++,
              label: 'Доступно через 40 мин (14:30)',
              unavailable: true,
              semanticsLabel: 'Недоступно до 14:30, нажмите для проверки',
            ),
          ),
        ),
      );
      expect(find.text('Доступно через 40 мин (14:30)'), findsOneWidget);
      await tester.tap(find.text('Доступно через 40 мин (14:30)'));
      expect(taps, 1);
    });

    testWidgets('announces itself as pressable with the deadline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            height: 80,
            child: RouteStartButton(
              onPressed: () {},
              label: 'Доступно через 40 мин (14:30)',
              unavailable: true,
              semanticsLabel: 'Недоступно до 14:30, нажмите для проверки',
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Недоступно до 14:30, нажмите для проверки'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
