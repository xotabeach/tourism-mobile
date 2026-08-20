import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_reviews_section.dart';
import 'package:tourism_mobile/features/profile/presentation/travelers_leaderboard_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('leaderboard follows current-user and podium composition', (
    tester,
  ) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(HomeScreen));
    unawaited(
      GoRouter.of(context).pushNamed(AppRouteNames.travelersLeaderboard),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TravelersLeaderboardScreen), findsOneWidget);
    expect(find.text('Топ путешественников:'), findsOneWidget);
    expect(find.text('Рейтинг по очкам Тревел Поинт (тп)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('leaderboard-current-user')),
      findsOneWidget,
    );
    expect(find.text('Вы'), findsOneWidget);
    expect(find.text('Топ 1'), findsWidgets);
    expect(find.textContaining(' / '), findsWidgets);
  });

  testWidgets(
    'place card exposes gallery actions, related routes and reviews',
    (tester) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(HomeScreen));
      unawaited(
        GoRouter.of(context).pushNamed(
          AppRouteNames.placeDetails,
          pathParameters: {'id': 'mock-ai-petri'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaceDetailsScreen), findsOneWidget);
      expect(find.text('Ай-Петри'), findsWidgets);
      expect(find.text('Посмотреть на карте'), findsOneWidget);
      expect(find.bySemanticsLabel('Поделиться'), findsOneWidget);
      expect(find.text('Маршруты с этим местом:'), findsOneWidget);
      expect(find.byType(PlaceReviewsSection), findsOneWidget);

      await tester.ensureVisible(find.text('Ваш отзыв:'));
      await tester.pumpAndSettle();
      expect(find.text('Поделитесь впечатлениями о месте'), findsOneWidget);
      expect(find.text('Добавить фото 0/6'), findsOneWidget);
    },
  );
}
