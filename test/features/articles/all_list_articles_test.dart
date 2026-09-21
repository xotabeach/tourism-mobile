import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/data/mock_articles_repository.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/home/presentation/all_list_screen.dart';

import '../../support/test_overrides.dart';

void main() {
  testWidgets('the Блоги tab lists articles instead of spinning forever', (
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(
          home: AllListScreen(initialMode: HomeListMode.articles),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The loader used to fall through to places in this mode, so the article
    // list stayed empty and the spinner never went away.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ArticleCard), findsWidgets);
  });

  testWidgets('blogs can be sorted: newest, oldest, popular', (tester) async {
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
        child: const MaterialApp(
          home: AllListScreen(initialMode: HomeListMode.articles),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Сортировка'));
    await tester.pumpAndSettle();

    expect(find.text('Сначала новые'), findsOneWidget);
    expect(find.text('Сначала старые'), findsOneWidget);
    expect(find.text('По популярности'), findsOneWidget);
    // A blog title is not an order anyone looks for.
    expect(find.text('По названию (А–Я)'), findsNothing);

    await tester.tap(find.text('Сначала старые'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticleCard), findsWidgets);
  });

  test('the mock feed honours every sort', () async {
    final repo = MockArticlesRepository();
    DateTime date(ArticleSummary a) =>
        a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    final newest = (await repo.listArticles()).items;
    final oldest = (await repo.listArticles(
      sort: ArticleFeedSort.oldest,
    )).items;
    final popular = (await repo.listArticles(
      sort: ArticleFeedSort.popular,
    )).items;

    for (var i = 1; i < newest.length; i++) {
      expect(date(newest[i - 1]).isBefore(date(newest[i])), isFalse);
      expect(date(oldest[i - 1]).isAfter(date(oldest[i])), isFalse);
      expect(popular[i - 1].likeCount >= popular[i].likeCount, isTrue);
    }
  });
}
