import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

import '../support/test_overrides.dart';

/// Reports one active run whose route is gone — the state a deleted route
/// leaves behind, since the FK sets `route_id` to NULL rather than removing
/// the run itself.
class _OrphanedExecutionRepository implements RouteExecutionRepository {
  var cancelledId = '';

  static final orphan = RouteExecution(
    id: 'exec-orphan',
    routeName: 'еще один тест',
    status: RouteExecutionStatus.active,
    startedAt: DateTime(2026, 8, 30),
    totalStops: 2,
    completedStops: 0,
    requiredStops: 2,
    completedRequiredStops: 0,
    stops: const [],
  );

  @override
  Future<List<RouteExecution>> list({int limit = 20, int offset = 0}) async => [
    orphan,
  ];

  @override
  Future<RouteExecution> cancel(
    String executionId, {
    String? clientEventId,
    DateTime? occurredAt,
  }) async {
    cancelledId = executionId;
    return orphan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

void main() {
  testWidgets('an active run whose route was deleted can still be ended', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1400);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final repository = _OrphanedExecutionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          routeExecutionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MyRoutesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();

    // The backend refuses to start any new route while a run is active
    // (active_route_execution_exists), so a tile with no way out would lock
    // the account out of route execution entirely.
    final prompt = find.text('Маршрут удалён · нажмите, чтобы завершить');
    expect(prompt, findsOneWidget);

    await tester.tap(prompt, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Завершить прохождение?'), findsOneWidget);
    await tester.tap(find.text('Завершить'));
    await tester.pumpAndSettle();

    expect(repository.cancelledId, 'exec-orphan');
  });
}
