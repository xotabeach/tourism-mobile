import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('iOS chat swipe cancels or returns to the parameter form', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      final router = GoRouter(
        initialLocation: '/match',
        routes: [
          GoRoute(
            path: '/match',
            builder: (_, _) => const RouteMatchScreen(),
            routes: [
              GoRoute(
                path: 'chat',
                pageBuilder: (_, state) => CupertinoPage<void>(
                  key: state.pageKey,
                  child: const RouteMatchScreen(initialMode: RouteMatchMode.ai),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testSessionOverrides(
            onboardingCompleted: true,
            travelPlusActive: true,
            travelPlusPlan: 'monthly',
            travelPlusExpiresAt: DateTime.now().add(const Duration(days: 10)),
          ),
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('route-mode-ai')));
      await tester.pumpAndSettle();
      expect(find.text('Тревел Агент'), findsWidgets);

      final cancel = await tester.startGesture(const Offset(2, 400));
      await cancel.moveBy(const Offset(65, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await cancel.up();
      await tester.pumpAndSettle();
      expect(find.text('Тревел Агент'), findsWidgets);

      await tester.dragFrom(
        const Offset(2, 400),
        const Offset(340, 0),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/match');
      expect(find.text('Тревел Агент'), findsNothing);
      expect(find.byKey(const ValueKey('route-mode-params')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });
}
