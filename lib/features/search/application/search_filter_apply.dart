import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/search/presentation/search_filters_sheet.dart';

/// Применение [SearchFilters] к уже загруженным спискам.
///
/// На Главной шторка фильтрует выдачу поиска, в Избранном — сам список
/// раздела. Логика одна и та же, поэтому она живёт здесь, а не дублируется
/// в двух экранах.
/// Слова тега и то, как они выглядят в тексте карточки.
///
/// Тег — это слово для человека («Горы»), а в описании стоит «горный».
/// Совпадение по корню было в фильтре каталога маршрутов и переехало сюда,
/// чтобы шторка на Главной и в Избранном искала одинаково.
const _tagKeywords = <String, List<String>>{
  'Море': ['море', 'морск', 'берег', 'фиолент', 'свет', 'бухт'],
  'Горы': ['гор', 'петри', 'бахчисар', 'кале', 'скал'],
  'Еда': ['еда', 'кухн', 'вин', 'сыр', 'гастроном'],
  'Лес': ['лес', 'троп', 'сосн', 'заповед'],
  'Романтика': ['романт', 'закат', 'вид'],
  'С детьми': ['дет', 'семей'],
  'Сложные': ['hard', 'сложн'],
  'Отдых': ['легк', 'easy', 'отдых', 'пляж'],
  'История': ['истор', 'крепост', 'музе', 'древн'],
  'Личный опыт': ['опыт', 'личн'],
  'Лайфхаки': ['лайфхак', 'совет'],
};

bool matchesSearchTags(String haystack, Set<String> tags) {
  if (tags.isEmpty) {
    return true;
  }
  for (final tag in tags) {
    final keywords = _tagKeywords[tag] ?? [tag.toLowerCase()];
    if (keywords.any(haystack.contains)) {
      return true;
    }
  }
  return false;
}

String routeSearchHaystack(RouteSummary route) =>
    '${route.name} ${route.shortDescription ?? ''} '
            '${route.authorLabel ?? ''} ${route.difficulty ?? ''} '
            '${route.transportMode ?? ''} ${route.seasonality.join(' ')}'
        .toLowerCase();

String placeSearchHaystack(PlaceSummary place) =>
    '${place.name} ${place.shortDescription ?? ''} '
            '${place.categories.map((c) => c.name).join(' ')} '
            '${place.difficulty ?? ''}'
        .toLowerCase();

String articleSearchHaystack(ArticleSummary article) =>
    '${article.title} ${article.excerpt ?? ''} ${article.tags.join(' ')}'
        .toLowerCase();

List<RouteSummary> applyRouteFilters(
  List<RouteSummary> items,
  SearchFilters filters,
) {
  final result = items
      .where(
        (route) => matchesSearchTags(routeSearchHaystack(route), filters.tags),
      )
      .toList();
  switch (filters.sort) {
    case SearchSort.rating:
      // Маршруты без единой оценки уходят вниз, а не притворяются нулём.
      result.sort(
        (a, b) => (b.ratingAverage ?? -1).compareTo(a.ratingAverage ?? -1),
      );
    case SearchSort.popular:
      result.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    case SearchSort.alphabetical:
      result.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case SearchSort.byDefault:
    case SearchSort.newest:
    case SearchSort.oldest:
      break;
  }
  return result;
}

List<PlaceSummary> applyPlaceFilters(
  List<PlaceSummary> items,
  SearchFilters filters,
) {
  final result = items
      .where(
        (place) => matchesSearchTags(placeSearchHaystack(place), filters.tags),
      )
      .toList();
  if (filters.sort == SearchSort.alphabetical) {
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return result;
}

List<ArticleSummary> applyArticleFilters(
  List<ArticleSummary> items,
  SearchFilters filters,
) {
  final result = items
      .where(
        (article) =>
            matchesSearchTags(articleSearchHaystack(article), filters.tags),
      )
      .toList();
  DateTime dateOf(ArticleSummary a) => a.publishedAt ?? a.createdAt;
  switch (filters.sort) {
    case SearchSort.popular:
      result.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    case SearchSort.newest:
      result.sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    case SearchSort.oldest:
      result.sort((a, b) => dateOf(a).compareTo(dateOf(b)));
    case SearchSort.alphabetical:
      result.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case SearchSort.byDefault:
    case SearchSort.rating:
      break;
  }
  return result;
}

List<PublicUserProfile> applyProfileFilters(
  List<PublicUserProfile> items,
  SearchFilters filters,
) {
  final result = [...items];
  switch (filters.sort) {
    case SearchSort.popular:
      // «Популярность» профиля — это его тревел-очки, другого счётчика нет.
      result.sort((a, b) => b.travelPoints.compareTo(a.travelPoints));
    case SearchSort.alphabetical:
      result.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    case SearchSort.byDefault:
    case SearchSort.rating:
    case SearchSort.newest:
    case SearchSort.oldest:
      break;
  }
  return result;
}

List<RouteExecution> applyExecutionFilters(
  List<RouteExecution> items,
  SearchFilters filters,
) {
  final result = [...items];
  switch (filters.sort) {
    case SearchSort.newest:
      result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    case SearchSort.oldest:
      result.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    case SearchSort.byDefault:
    case SearchSort.rating:
    case SearchSort.popular:
    case SearchSort.alphabetical:
      break;
  }
  return result;
}
