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
/// "Статья о маршруте"). The links must therefore navigate with `go`.
///
/// The router below mirrors that structure — a top-level route plus a shell
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

void main() {
  testWidgets('the related-route link lands on the route, not a blank page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final article = Article(
      id: 'article-1',
      title: 'статья 1',
      status: ArticleStatus.published,
      authorUserId: 'author-1',
      authorDisplayName: 'Некич',
      createdAt: DateTime.utc(2026, 9, 3),
      relatedRouteId: 'route-7',
    );

    final shellKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      initialLocation: '/articles/article-1',
      routes: [
        GoRoute(
          path: '/articles/:id',
          name: AppRouteNames.articleDetails,
          builder: (context, state) =>
              ArticleDetailsScreen(articleId: state.pathParameters['id']!),
        ),
        ShellRoute(
          navigatorKey: shellKey,
          builder: (context, state, child) =>
              Scaffold(body: child, bottomNavigationBar: const SizedBox(height: 40)),
          routes: [
            GoRoute(
              path: '/routes',
              builder: (context, state) => const Text('каталог'),
              routes: [
                GoRoute(
                  path: ':id',
                  name: AppRouteNames.routeDetails,
                  builder: (context, state) =>
                      Text('маршрут ${state.pathParameters['id']}'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          articlesRepositoryProvider.overrideWithValue(
            _StubArticlesRepository(article),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Статья о маршруте'));
    await tester.pumpAndSettle();

    expect(find.text('маршрут route-7'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/routes/route-7');
  });
}
