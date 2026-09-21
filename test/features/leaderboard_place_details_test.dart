import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/places/presentation/place_reviews_section.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/profile/presentation/travelers_leaderboard_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../support/test_overrides.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
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
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          ...overrides,
        ],
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    final welcomeCta = find.text('Начать путешествие');
    if (welcomeCta.evaluate().isNotEmpty) {
      await tester.tap(welcomeCta);
      await tester.pumpAndSettle();
    }
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

  testWidgets('an expert sees their card without a place or points', (
    tester,
  ) async {
    // The server leaves an expert's place empty: they are not in the rating.
    await pumpApp(
      tester,
      overrides: [
        currentLeaderboardTravelerProvider.overrideWith(
          (ref) async => const PublicUserProfile(
            id: 'expert-me',
            displayName: 'Эксперт',
            travelPoints: 88,
            rankTitle: 'Эксперт',
            isExpert: true,
          ),
        ),
      ],
    );
    final context = tester.element(find.byType(HomeScreen));
    unawaited(
      GoRouter.of(context).pushNamed(AppRouteNames.travelersLeaderboard),
    );
    await tester.pumpAndSettle();

    final own = find.byKey(const ValueKey('leaderboard-current-user'));
    expect(own, findsOneWidget);
    expect(find.descendant(of: own, matching: find.text('Вы')), findsOneWidget);
    expect(
      find.descendant(
        of: own,
        matching: find.text('Эксперты не участвуют в рейтинге'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: own, matching: find.textContaining('Топ ')),
      findsNothing,
    );
    expect(
      find.descendant(of: own, matching: find.textContaining(' тп')),
      findsNothing,
    );
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
      expect(find.text('Фото 0/6'), findsOneWidget);
      expect(find.textContaining('Слушать аудиогид'), findsNothing);
      expect(find.bySemanticsLabel('Слушать аудиогид'), findsOneWidget);
    },
  );
}
