import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/chat_history_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

import '../support/test_overrides.dart';

const _historySession = RoutePlanningSession(
  sessionId: 'mock-session-history-1',
  status: 'closed',
  constraints: RouteMatchParams(
    city: 'Ялта',
    duration: RouteDurationOption.d3_5,
    people: 2,
    interests: ['Море', 'Романтика'],
    pace: RoutePace.calm,
  ),
  aiPlanningEnabled: true,
);

void main() {
  testWidgets('chat history screen lists the seeded past session', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ChatHistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Seeded by MockRouteMatchRepository — label built from constraints.
    expect(find.textContaining('Ялта'), findsOneWidget);
  });

  testWidgets(
    'resuming a session replays its transcript instead of the starter greeting',
    (tester) async {
      final container = ProviderContainer(
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          travelPlusActive: true,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RouteMatchScreen(resumeSession: _historySession),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Подбери спокойный маршрут по Ялте на выходные'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Выбери из предложенного или опиши'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'back from a resumed session pops to the page that pushed it, not Home',
    (tester) async {
      // Regression: RouteMatchScreen._goBack() used to hardcode
      // context.go('/') for every instance (correct for the bottom-tab
      // root, which has no route to pop to) — a resumed session pushed
      // on top of ChatHistoryScreen was stranded back at Home instead of
      // returning to the list it came from.
      final container = ProviderContainer(
        overrides: testSessionOverrides(
          onboardingCompleted: true,
          travelPlusActive: true,
        ),
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/history',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Home placeholder')),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const ChatHistoryScreen(),
            routes: [
              GoRoute(
                path: 'resume',
                builder: (context, state) =>
                    const RouteMatchScreen(resumeSession: _historySession),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.push('/history/resume'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteMatchScreen), findsOneWidget);

      tester.widget<AppEdgeBackGesture>(find.byType(AppEdgeBackGesture)).onBack();
      await tester.pumpAndSettle();

      expect(find.byType(ChatHistoryScreen), findsOneWidget);
      expect(find.text('Home placeholder'), findsNothing);
    },
  );

  test('routeMatchDurationLabel covers every duration option', () {
    for (final option in RouteDurationOption.values) {
      expect(routeMatchDurationLabel(option), isNotEmpty);
    }
  });
}
