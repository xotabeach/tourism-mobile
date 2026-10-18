import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/route_execution/application/live_location_provider.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

class _Repo extends MockRouteExecutionRepository {
  _Repo({this.undeliveredStopId, this.located = false});

  /// Stops carry coordinates, a few hundred metres apart.
  final bool located;
  final marked = <String>[];

  @override
  Future<RouteExecution> completeStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
    MarkPosition? position,
  }) async {
    marked.add(stopId);
    final run = _run!;
    final stops = [
      for (final stop in run.stops)
        stop.id == stopId ? stop.copyWith(completedAt: DateTime.now()) : stop,
    ];
    return _run = run.copyWith(
      stops: stops,
      completedStops: stops.where((stop) => stop.isCompleted).length,
    );
  }

  var completes = 0;
  var cancels = 0;

  @override
  Future<RouteExecution> complete(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    completes += 1;
    return _run = _run!.copyWith(
      status: RouteExecutionStatus.completed,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    cancels += 1;
    return _run = _run!.copyWith(
      status: RouteExecutionStatus.cancelled,
      cancelledAt: DateTime.now(),
    );
  }

  /// A stop whose offline mark never reached the server (DESIGN-4, №3).
  final String? undeliveredStopId;
  final unmarked = <String>[];
  final skipped = <String>[];
  final unskipped = <String>[];
  var starts = 0;
  RouteExecution? _run;

  @override
  Future<RouteExecution> skipStop(
    String executionId,
    String stopId, {
    required StopSkipReason reason,
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    skipped.add('$stopId:${reason.apiName}');
    final run = _run!;
    return _run = run.copyWith(
      stops: [
        for (final stop in run.stops)
          stop.id == stopId ? stop.skipped(reason, DateTime.now()) : stop,
      ],
    );
  }

  @override
  Future<RouteExecution> unskipStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    unskipped.add(stopId);
    final run = _run!;
    return _run = run.copyWith(
      stops: [
        for (final stop in run.stops)
          stop.id == stopId ? stop.withoutSkip() : stop,
      ],
    );
  }

  @override
  Future<RouteExecution> uncompleteStop(
    String executionId,
    String stopId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    unmarked.add(stopId);
    final run = _run!;
    final stops = [
      for (final stop in run.stops)
        stop.id == stopId ? stop.withoutCompletion() : stop,
    ];
    return _run = run.copyWith(
      stops: stops,
      completedStops: stops.where((stop) => stop.isCompleted).length,
    );
  }

  @override
  Future<RouteExecution> start(
    String routeId, {
    String? companionGroupId,
    DateTime? startedAt,
  }) async {
    starts += 1;
    final now = DateTime.now();
    return _run = RouteExecution(
      id: 'run-1',
      routeId: routeId,
      routeName: 'Алушта: от гор к набережной',
      status: RouteExecutionStatus.active,
      startedAt: now.subtract(const Duration(minutes: 174)),
      totalStops: 4,
      completedStops: 1,
      requiredStops: 4,
      completedRequiredStops: 1,
      stops: [
        for (var i = 0; i < 4; i++)
          RouteExecutionStop(
            id: 's$i',
            position: i + 1,
            placeName: 'Точка ${i + 1}',
            isOptional: false,
            lat: located ? 44.60 + i * 0.01 : null,
            lng: located ? 34.40 : null,
            legDistanceMeters: i == 0 ? null : 3500,
            legEstimateSeconds: i == 0 ? null : 2400,
            completedAt: i == 0 ? now : null,
            undelivered: 's$i' == undeliveredStopId,
          ),
      ],
    );
  }
}

Future<void> _openRunScreen(
  WidgetTester tester,
  _Repo repo, {
  bool openOnly = false,
  List<Override> overrides = const [],
}) async {
  for (final channel in [
    'flutter.baseflow.com/geolocator',
    'flutter.baseflow.com/geolocator_updates',
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => switch (call.method) {
        'checkPermission' || 'requestPermission' => 2,
        'isLocationServiceEnabled' => true,
        _ => null,
      },
    );
  }
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 1400);
  addTearDown(tester.view.reset);
  await pumpTourismAppAtHome(
    tester,
    overrides: [
      routeExecutionRepositoryProvider.overrideWithValue(repo),
      ...overrides,
    ],
  );
  unawaited(
    GoRouter.of(tester.element(find.byType(HomeScreen))).pushNamed(
      AppRouteNames.routeExecution,
      pathParameters: {'id': 'route-south-coast'},
      queryParameters: openOnly ? const {'open': '1'} : const {},
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets(
    'the route can be finished with stops left open, after a question',
    (tester) async {
      // FRONTEND-91: one of four marked, «Завершить маршрут» asks and finishes.
      final repo = _Repo();
      await _openRunScreen(tester, repo);
      await tester.ensureVisible(find.bySemanticsLabel('Завершить маршрут'));
      await tester.tap(find.bySemanticsLabel('Завершить маршрут'));
      await tester.pumpAndSettle();
      expect(find.text('Завершить маршрут?'), findsOneWidget);
      expect(find.textContaining('Отмечено 1 из 4'), findsOneWidget);
      await tester.tap(find.text('Продолжить путь'));
      await tester.pumpAndSettle();
      expect(repo.completes, 0);

      await tester.tap(find.bySemanticsLabel('Завершить маршрут'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.completes, 1);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('with nothing marked «Завершить маршрут» offers to call it off', (
    tester,
  ) async {
    final repo = _Repo();
    await _openRunScreen(tester, repo);
    await tester.tap(
      find.bySemanticsLabel('«Точка 1» отмечена, снять отметку'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Снять отметку'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.bySemanticsLabel('Завершить маршрут'));
    await tester.tap(find.bySemanticsLabel('Завершить маршрут'));
    await tester.pumpAndSettle();
    expect(find.text('Ни одна точка не отмечена'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Отменить прохождение'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((repo.completes, repo.cancels), (0, 1));
    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the run screen follows the design layout', (tester) async {
    await _openRunScreen(tester, _Repo());
    expect(find.byType(RouteExecutionScreen), findsOneWidget);
    expect(find.text('Прохождение'), findsOneWidget);
    expect(find.text('Прогресс:'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.bySemanticsLabel('Всего в пути: 174 мин.'), findsOneWidget);
    expect(find.text('Остановки:'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Пауза'), findsOneWidget);
    expect(
      find.bySemanticsLabel('«Точка 1» отмечена, снять отметку'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Отметить «Точка 2»'), findsOneWidget);
    expect(find.text('3,5 км • ≈ 40 мин'), findsWidgets);
    // Without a location fix the row says it is the whole leg, not a distance
    // from the phone.
    expect(find.text('весь участок 3,5 км'), findsOneWidget);
    expect(find.bySemanticsLabel('Завершить маршрут'), findsOneWidget);
    // FRONTEND-22: the leg being walked is named above the map and its
    // target row is marked as the next one.
    expect(find.text('Сейчас в пути · участок 1–2'), findsOneWidget);
    expect(find.text('Следующая • 3,5 км • ≈ 40 мин'), findsOneWidget);
    // The separate «Пауза» button and the old «Готово» buttons are gone.
    expect(find.text('Готово'), findsNothing);

    // Leave the screen so its minute clock is disposed.
    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the latest mark can be taken back after a confirmation', (
    tester,
  ) async {
    final repo = _Repo();
    await _openRunScreen(tester, repo);

    await tester.tap(
      find.bySemanticsLabel('«Точка 1» отмечена, снять отметку'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Снять отметку?'), findsOneWidget);
    await tester.tap(find.text('Снять отметку'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.unmarked, ['s0']);
    expect(find.text('0/4'), findsOneWidget);
    expect(find.bySemanticsLabel('Отметить «Точка 1»'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the next stop is skipped with a reason and can be taken back', (
    tester,
  ) async {
    final repo = _Repo();
    await _openRunScreen(tester, repo);
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Only the stop being walked to offers the skip.
    expect(find.text('Пропустить точку'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Пропустить «Точка 2»'));
    await tester.pumpAndSettle();
    expect(find.text('Пропустить «Точка 2»?'), findsOneWidget);
    for (final reason in StopSkipReason.pickable) {
      expect(find.text(reason.label), findsOneWidget);
    }
    // «Не дошёл» is the server's, for a run finished early (FRONTEND-91).
    expect(find.text(StopSkipReason.notReached.label), findsNothing);
    await tester.tap(find.text('Закрыто'));
    await tester.pumpAndSettle();
    await settle();

    expect(repo.skipped, ['s1:closed']);
    expect(find.text('Пропущена • Закрыто'), findsOneWidget);
    // The walk moves on: the next stop is the one after the skipped.
    expect(find.bySemanticsLabel('Пропустить «Точка 3»'), findsOneWidget);
    expect(find.text('Сейчас в пути · участок 2–3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('«Точка 2» пропущена, вернуть'));
    await settle();

    expect(repo.unskipped, ['s1']);
    expect(find.text('Пропущена • Закрыто'), findsNothing);
    expect(find.bySemanticsLabel('Отметить «Точка 2»'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping a stop opens its card without leaving the run', (
    tester,
  ) async {
    await _openRunScreen(tester, _Repo());

    await tester.tap(find.text('Точка 3'));
    await tester.pumpAndSettle();

    // The name is now on the row and on the card.
    expect(find.text('Точка 3'), findsNWidgets(2));
    expect(find.byType(RouteExecutionScreen), findsOneWidget);
    Navigator.of(
      tester.element(find.text('Точка 3').last),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('Точка 3'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('near a stop the screen offers to mark it', (tester) async {
    final repo = _Repo(located: true);
    Position at(double lat) => Position(
      latitude: lat,
      longitude: 34.40,
      timestamp: DateTime.now(),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await _openRunScreen(
      tester,
      repo,
      overrides: [
        // ~55 m from «Точка 2».
        liveLocationProvider.overrideWith((ref) => Stream.value(at(44.6105))),
      ],
    );
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.text('Вы рядом с точкой «Точка 2»'), findsOneWidget);

    await tester.tap(find.text('Отметить'));
    await settle();

    expect(repo.marked, ['s1']);
    expect(find.text('2/4'), findsOneWidget);
    // Marked: nothing left to offer here.
    expect(find.textContaining('Вы рядом с точкой'), findsNothing);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('«не сейчас» puts the hint away for that stop', (tester) async {
    final repo = _Repo(located: true);
    await _openRunScreen(
      tester,
      repo,
      overrides: [
        liveLocationProvider.overrideWith(
          (ref) => Stream.value(
            Position(
              latitude: 44.6105,
              longitude: 34.40,
              timestamp: DateTime.now(),
              accuracy: 12,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
          ),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Вы рядом с точкой «Точка 2»'), findsOneWidget);

    await tester.tap(find.text('Не сейчас'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Вы рядом с точкой'), findsNothing);
    expect(repo.marked, isEmpty);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('closing the reason sheet skips nothing', (tester) async {
    final repo = _Repo();
    await _openRunScreen(tester, repo);

    await tester.tap(find.bySemanticsLabel('Пропустить «Точка 2»'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.text('Пропустить «Точка 2»?')),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    expect(repo.skipped, isEmpty);
    expect(find.bySemanticsLabel('Отметить «Точка 2»'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('opened from the home card, a finished run is not restarted', (
    tester,
  ) async {
    // FRONTEND-34: the card can outlive its run (finished on another
    // device); tapping it must not start the route again.
    final repo = _Repo();
    await _openRunScreen(tester, repo, openOnly: true);

    expect(repo.starts, 0);
    expect(find.text('Прохождение уже завершено'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an undelivered mark shows the red cross and a retry note', (
    tester,
  ) async {
    await _openRunScreen(tester, _Repo(undeliveredStopId: 's1'));

    // DESIGN-4 №1: leg length and time with a bullet.
    expect(find.text('3,5 км • ≈ 40 мин'), findsWidgets);
    // №3: the note next to the stop, the cross in place of the ring.
    expect(
      find.text('Что-то пошло не так,\nпопробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Отметка «Точка 2» не доставлена, отметить заново'),
      findsOneWidget,
    );

    GoRouter.of(tester.element(find.byType(RouteExecutionScreen))).pop();
    await tester.pump(const Duration(seconds: 1));
  });
}
