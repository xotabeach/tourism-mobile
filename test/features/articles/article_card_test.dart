import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';

import '../../support/test_overrides.dart';

ArticleSummary _summary({
  ArticleStatus status = ArticleStatus.published,
  List<String> tags = const [],
  int likeCount = 0,
  bool likedByMe = false,
  int readingTimeMinutes = 4,
  String? excerpt,
  String? authorRankTitle,
}) {
  return ArticleSummary(
    id: 'article-1',
    title: 'Три дня на Южном берегу без машины',
    status: status,
    authorUserId: 'author-1',
    authorDisplayName: 'Никита',
    createdAt: DateTime.utc(2026, 8, 1),
    publishedAt: DateTime.utc(2026, 8, 2),
    tags: tags,
    likeCount: likeCount,
    likedByMe: likedByMe,
    readingTimeMinutes: readingTimeMinutes,
    excerpt: excerpt,
    authorRankTitle: authorRankTitle,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  ArticleSummary article, {
  double width = 290,
  double height = 320,
  bool showStatus = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ArticleCard(
              article: article,
              width: width,
              height: height,
              showStatus: showStatus,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/articles/:id',
        name: 'article-details',
        builder: (context, state) =>
            Scaffold(body: Text('Article ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, author and reading time', (tester) async {
    await _pumpCard(tester, _summary());

    expect(find.text('Три дня на Южном берегу без машины'), findsOneWidget);
    expect(find.text('Никита'), findsOneWidget);
    expect(find.text('4 мин'), findsOneWidget);
  });

  testWidgets('shows only the leading tag over the photo', (tester) async {
    await _pumpCard(
      tester,
      _summary(tags: const ['История', 'Пешком', 'Море']),
    );

    expect(find.text('История'), findsOneWidget);
    expect(find.text('Пешком'), findsNothing);
    expect(find.text('Море'), findsNothing);
  });

  testWidgets('shows the excerpt and the author rank under the name', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _summary(
        excerpt: 'Маршрут занял три полных дня.',
        authorRankTitle: 'Продвинутый пешеход',
      ),
    );

    expect(find.text('Маршрут занял три полных дня.'), findsOneWidget);
    expect(find.text('Продвинутый пешеход'), findsOneWidget);
  });

  testWidgets('shows the publication date on the photo', (tester) async {
    await _pumpCard(tester, _summary());

    expect(find.text('02.08.2026'), findsOneWidget);
  });

  testWidgets('shows a filled heart and the like count when liked', (
    tester,
  ) async {
    await _pumpCard(tester, _summary(likeCount: 42, likedByMe: true));

    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('shows a status pill for a draft only when showStatus is set', (
    tester,
  ) async {
    final draft = _summary(status: ArticleStatus.draft);

    await _pumpCard(tester, draft);
    expect(find.text('Черновик'), findsNothing);

    await _pumpCard(tester, draft, showStatus: true);
    expect(find.text('Черновик'), findsOneWidget);
  });

  testWidgets('never shows a status pill for a published article', (
    tester,
  ) async {
    await _pumpCard(tester, _summary(), showStatus: true);

    expect(find.text('Черновик'), findsNothing);
    expect(find.text('На модерации'), findsNothing);
    expect(find.text('Отклонена'), findsNothing);
  });

  testWidgets('tapping the card opens the article details route', (
    tester,
  ) async {
    await _pumpCard(tester, _summary());

    await tester.tap(find.byType(ArticleCard));
    await tester.pumpAndSettle();

    expect(find.text('Article article-1'), findsOneWidget);
  });
}
