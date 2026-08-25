import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/profile/presentation/achievements_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../support/test_overrides.dart';

void main() {
  Widget _app(Widget home) {
    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }

  testWidgets('home error keeps the greeting header', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(
            onboardingCompleted: true,
            displayName: 'Никита',
          ),
          homeRoutesProvider.overrideWith((ref) async {
            throw Exception('secret-db-url');
          }),
        ],
        child: _app(const Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    expect(find.byType(AppAsyncErrorView), findsOneWidget);
    expect(find.textContaining('secret-db-url'), findsNothing);
  });

  testWidgets('my routes loading keeps title chrome', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          routesListProvider.overrideWith(
            (ref) => Completer<RouteListPage>().future,
          ),
          placesListProvider.overrideWith(
            (ref) async =>
                const PlaceListPage(items: [], total: 0, limit: 20, offset: 0),
          ),
          profileSubscriptionsProvider.overrideWith((ref) async => []),
        ],
        child: _app(const Scaffold(body: MyRoutesScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('Моё избранное:'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('my routes error does not dump exception text', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          routesListProvider.overrideWith((ref) async {
            throw Exception('secret-token');
          }),
          placesListProvider.overrideWith(
            (ref) async =>
                const PlaceListPage(items: [], total: 0, limit: 20, offset: 0),
          ),
          profileSubscriptionsProvider.overrideWith((ref) async => []),
        ],
        child: _app(const Scaffold(body: MyRoutesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Моё избранное:'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(find.byType(AppAsyncErrorView), findsOneWidget);
  });

  testWidgets('achievements loading keeps filter and search', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          userAchievementsProvider.overrideWith(
            (ref, userId) => Completer<List<ProfileAchievement>>().future,
          ),
        ],
        child: _app(const AchievementsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Достижения:'), findsOneWidget);
    expect(find.text('Искать достижение'), findsOneWidget);
    expect(find.text('Полученные'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
