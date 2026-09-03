import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_details_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

/// ArticleDetailsScreen is declared outside StatefulShellRoute; route details
/// and user profiles live inside tab branches. A `push` from the root
/// navigator into a branch route trips Navigator's duplicate-page-key
/// assertion, and the user is left on a blank screen whose content only
/// flickers in during the back-swipe (reported 2026-09-03 for
/// "Статья о маршруте"). Both links therefore go through root-navigator
/// variants of those screens, which also keeps the article underneath so
/// back returns to it instead of dumping the reader on a tab.
///
/// The router below mirrors that structure — top-level routes plus a shell
/// branch — rather than booting the whole app, which drags in unrelated
/// app-wide timers.
class _StubArticlesRepository implements ArticlesRepository {
  _StubArticlesRepository(this.article);

  final Article article;

  @override
  Future<Article> getArticle(String id) async => article;

  @override
  Future<ArticleListPage> listRelated(String articleId) async =>
      const ArticleListPage(items: [], total: 0);

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) async => const ArticleCommentPage(items: [], total: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

GoRouter _router() {
  final article = Article(
    id: 'article-1',
    title: 'статья 1',
    status: ArticleStatus.published,
    authorUserId: 'author-1',
    authorDisplayName: 'Некич',
    createdAt: DateTime.utc(2026, 9, 3),
    relatedRouteId: 'route-7',
  );
  _stubArticle = article;

  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: '/articles/article-1',
    routes: [
      GoRoute(
        path: '/articles/:id',
        name: AppRouteNames.articleDetails,
        builder: (context, state) =>
            ArticleDetailsScreen(articleId: state.pathParameters['id']!),
      ),
      // Standalone-варианты: корневой навигатор, как в настоящем роутере.
      GoRoute(
        path: '/route/:id',
        name: AppRouteNames.routeDetailsStandalone,
        builder: (context, state) =>
            Text('маршрут ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/user/:userId',
        name: AppRouteNames.userProfileStandalone,
        builder: (context, state) =>
            Text('профиль ${state.pathParameters['userId']}'),
      ),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => Scaffold(
          body: child,
          bottomNavigationBar: const SizedBox(height: 40),
        ),
        routes: [
          GoRoute(
            path: '/routes',
            builder: (context, state) => const Text('каталог'),
            routes: [
              GoRoute(
                path: ':id',
                name: AppRouteNames.routeDetails,
                builder: (context, state) =>
                    Text('в табе ${state.pathParameters['id']}'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

late Article _stubArticle;

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        articlesRepositoryProvider.overrideWithValue(
          _StubArticlesRepository(_stubArticle),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the related-route link opens the route and comes back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await _tap(tester, 'Статья о маршруте');
    expect(find.text('маршрут route-7'), findsOneWidget);

    // Главное — назад возвращает в статью, а не выкидывает на вкладку
    // маршрутов: ради этого экран и живёт на корневом навигаторе.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ArticleDetailsScreen), findsOneWidget);
    expect(find.text('маршрут route-7'), findsNothing);
  });

  testWidgets('the author link opens the profile and comes back too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await _tap(tester, 'Некич');
    expect(find.text('профиль author-1'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ArticleDetailsScreen), findsOneWidget);
  });
}
