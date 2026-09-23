import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/features/profile/data/achievements_repository.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/profile/presentation/achievement_celebration_host.dart';
import 'package:tourism_mobile/features/profile/presentation/widgets/achievement_progress.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../support/test_overrides.dart';

class _Awards extends AchievementsRepository {
  _Awards(this.items) : super(Dio());
  final List<ProfileAchievement> items;
  final seen = <String>{};
  @override
  Future<List<ProfileAchievement>> list({bool uncelebrated = false}) async =>
      items.where((item) => !seen.contains(item.id)).toList();
  @override
  Future<void> celebrate(List<String> ids) async {
    seen.addAll(ids);
  }
}

void main() {
  List<ProfileAchievement> awards(int count) => List.generate(
    count,
    (i) => ProfileAchievement(
      id: '$i',
      title: 'Награда $i',
      description: 'Условие',
      celebrated: false,
    ),
  );

  for (final count in [1, 3, 4]) {
    testWidgets('startup celebrates $count awards once with correct batching', (
      tester,
    ) async {
      final repo = _Awards(awards(count));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Stack(children: [AchievementCelebrationHost()]),
            ),
          ),
          GoRoute(
            path: '/achievements',
            name: AppRouteNames.achievements,
            builder: (_, state) => Text(
              'Открыто ${state.uri.queryParameters['achievementId'] ?? 'всё'}',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testSessionOverrides(onboardingCompleted: true),
            achievementsRepositoryProvider.overrideWithValue(repo),
            appRouterProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      if (count > 3) {
        expect(find.text('Вы получили 4 достижения'), findsOneWidget);
        expect(repo.seen.length, 4);
      } else {
        expect(find.text('Награда 0'), findsOneWidget);
        expect(repo.seen, {'0'});
        for (var i = 1; i < count; i++) {
          await tester.pump(const Duration(seconds: 5));
          await tester.pump();
          expect(find.text('Награда $i'), findsOneWidget);
        }
      }
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(
        find.text(count > 3 ? 'Открыто всё' : 'Открыто ${count - 1}'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }

  testWidgets('progress renders count and soon state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AchievementProgress(
                achievement: ProfileAchievement(
                  id: 'a',
                  title: 'A',
                  description: '',
                  progressCurrent: 43,
                  progressTarget: 100,
                ),
              ),
              AchievementProgress(
                achievement: ProfileAchievement(
                  id: 'b',
                  title: 'B',
                  description: '',
                  isSoon: true,
                  isUnlocked: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('43 из 100'), findsOneWidget);
    expect(find.text('Скоро'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .43,
    );
  });

  test('private achievement contract parses progress and celebration', () {
    final badge = ProfileAchievement.fromJson({
      'id': 'a',
      'title': 'A',
      'status': 'soon',
      'celebrated': false,
      'progress': {'current': 43, 'target': 100},
    });
    expect(badge.isSoon, isTrue);
    expect(badge.isUnlocked, isFalse);
    expect(badge.celebrated, isFalse);
    expect(badge.progressCurrent, 43);
  });

  testWidgets('difficulty 5 reads as very hard in the publish form', (
    tester,
  ) async {
    Widget selector(int value) => MaterialApp(
      home: Scaffold(
        body: RouteDifficultySelector(
          u: (v) => v,
          value: value,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(selector(4));
    expect(find.text('Сложность маршрута:'), findsOneWidget);
    await tester.pumpWidget(selector(5));
    expect(find.text('Сложность: очень сложный'), findsOneWidget);
  });
}
