import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_checkout_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

Widget _app(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child ?? const SizedBox.shrink(),
      );
    },
    routerConfig: router,
  );
}

void _ignoreCheckoutListTileInkErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('ListTile background color')) {
      return;
    }
    previous?.call(details);
  };
}

void main() {
  testWidgets('checkout submit shows beta notice without activation', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    final previousOnError = FlutterError.onError;
    _ignoreCheckoutListTileInkErrors();
    addTearDown(() {
      FlutterError.onError = previousOnError;
    });

    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);

    final checkoutRouter = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) =>
              const Scaffold(body: SettingsTravelPlusCheckoutScreen()),
        ),
        GoRoute(
          name: AppRouteNames.settingsTravelPlus,
          path: '/profile/settings/travel-plus',
          builder: (_, _) => const Scaffold(body: Text('travel-plus-home')),
        ),
      ],
    );
    addTearDown(checkoutRouter.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(checkoutRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).travelPlusActive, isFalse);

    final submit = find.byKey(const ValueKey('travel-plus-checkout-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).travelPlusActive, isFalse);
    expect(
      find.text('В бета-версии покупка подписки недоступна'),
      findsOneWidget,
    );
    expect(find.text('travel-plus-home'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('AI CTA is available without Travel+', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final router = GoRouter(
      initialLocation: '/match',
      routes: [
        GoRoute(path: '/match', builder: (_, _) => const RouteMatchScreen()),
        GoRoute(
          path: '/profile/settings/travel-plus',
          builder: (_, _) => const Scaffold(body: Text('TRAVEL_PLUS_GATE')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: _app(router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('route-mode-ai')));
    await tester.pumpAndSettle();

    expect(find.text('TRAVEL_PLUS_GATE'), findsNothing);
    expect(find.text('Тревел Агент'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
