import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_details_screen.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../../support/test_overrides.dart';

/// Внизу статьи стояла одна строка «Статья о маршруте» без самого маршрута,
/// а привязка к месту не показывалась вовсе — хотя редактор её предлагает.
/// На скрине дизайнера («Страница блога») это карточка с обложкой и
/// названием.
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

Article _article({String? routeId, String? placeId}) => Article(
  id: 'article-1',
  title: 'Не маршрут, а приключение',
  status: ArticleStatus.published,
  authorUserId: 'author-1',
  authorDisplayName: 'Никита',
  createdAt: DateTime.utc(2026, 9, 4),
  relatedRouteId: routeId,
  relatedPlaceId: placeId,
);

const _route = RouteDetail(
  id: 'route-7',
  name: 'Гора Чок-Сары-Кая',
  slug: 'chok-sary-kaya',
  shortDescription: 'Подъём с видом на бухту',
  stopsCount: 4,
  description: null,
  stops: [],
);

const _place = PlaceDetail(
  id: 'place-3',
  name: 'Вилла Мечта',
  slug: 'villa-mechta',
  shortDescription: 'Дом на набережной',
  lat: 44.5,
  lng: 34.2,
  categories: [],
  description: null,
  address: null,
  seasonality: [],
  safetyWarnings: [],
);

Future<void> _pump(WidgetTester tester, Article article) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 2200);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        articlesRepositoryProvider.overrideWithValue(
          _StubArticlesRepository(article),
        ),
        routeDetailProvider.overrideWith((ref, id) async => _route),
        placeDetailProvider.overrideWith((ref, id) async => _place),
      ],
      child: const MaterialApp(
        home: ArticleDetailsScreen(articleId: 'article-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the attached route shows up by name', (tester) async {
    await _pump(tester, _article(routeId: 'route-7'));

    expect(find.text('Гора Чок-Сары-Кая'), findsOneWidget);
    expect(find.text('Статья о маршруте'), findsOneWidget);
  });

  testWidgets('an attached place gets its own card', (tester) async {
    await _pump(tester, _article(placeId: 'place-3'));

    expect(find.text('Вилла Мечта'), findsOneWidget);
    expect(find.text('Статья о месте'), findsOneWidget);
    expect(find.text('Статья о маршруте'), findsNothing);
  });
}
