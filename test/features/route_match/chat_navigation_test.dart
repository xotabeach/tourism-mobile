import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';

import '../../support/test_overrides.dart';

/// The two modes are one screen: the selector morphs and the body swaps in
/// place. Pushing chat as its own page looked equivalent — the chat did open
/// — while quietly replacing that morph with a full screen sliding in. The
/// existing morph test could not catch it: it mounts the selector on its own
/// harness, so it stayed green while the real screen stopped morphing. These
/// tests drive the real screen instead.
Future<GoRouter> _pumpMatch(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  final router = GoRouter(
    initialLocation: RouteMatchScreen.routePath,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: RouteMatchScreen.routePath,
        builder: (_, _) => const RouteMatchScreen(),
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
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

double _widthOf(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).width;

void main() {
  testWidgets('switching to chat morphs the selector instead of pushing a page', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final router = await _pumpMatch(tester);
      final paramsWide = _widthOf(tester, 'route-mode-params');
      final aiNarrow = _widthOf(tester, 'route-mode-ai');
      expect(paramsWide, greaterThan(aiNarrow));

      await tester.tap(find.byKey(const ValueKey('route-mode-ai')));
      // Mid-flight: the two halves are still trading width. A pushed page
      // would instead slide a second copy of the screen over this one.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        _widthOf(tester, 'route-mode-ai'),
        greaterThan(aiNarrow + 1),
        reason: 'the selector must animate, not cut to the chat',
      );
      expect(find.byType(RouteMatchScreen), findsOneWidget);

      await tester.pumpAndSettle();
      expect(_widthOf(tester, 'route-mode-ai'), greaterThan(aiNarrow));
      expect(_widthOf(tester, 'route-mode-params'), lessThan(paramsWide));
      expect(find.text('Тревел Агент'), findsWidgets);
      // Chat is a mode of this screen, so the location never moved and no
      // second screen was stacked underneath.
      expect(router.routeInformationProvider.value.uri.path, '/match');
      expect(find.byType(RouteMatchScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('route-mode-params')));
      await tester.pumpAndSettle();
      expect(find.text('Тревел Агент'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/match');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('the edge swipe leaves for Home from either mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // Params mode.
      var router = await _pumpMatch(tester);
      await tester.dragFrom(const Offset(2, 400), const Offset(340, 0));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      await tester.pumpWidget(const SizedBox.shrink());

      // Chat mode: same gesture, same destination — nothing mode specific.
      router = await _pumpMatch(tester);
      await tester.tap(find.byKey(const ValueKey('route-mode-ai')));
      await tester.pumpAndSettle();
      expect(find.text('Тревел Агент'), findsWidgets);

      await tester.dragFrom(const Offset(2, 400), const Offset(340, 0));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });
}
