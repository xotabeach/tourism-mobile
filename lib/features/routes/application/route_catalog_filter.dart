import 'package:tourism_mobile/features/routes/domain/route.dart';

const routeCatalogFilters = ['Все', 'Море', 'Горы', 'Еда', 'Лес'];

List<RouteSummary> filterRouteCatalog(
  List<RouteSummary> routes,
  String selectedFilter,
) {
  if (selectedFilter == 'Все') {
    return routes;
  }
  if (selectedFilter == 'Море') {
    // The route's own tag decides; words in the title are only a fallback
    // for a server that does not send the tag yet.
    return routes
        .where(
          (route) => route.isSeaside ?? _matchesKeywords(route, _seaKeywords),
        )
        .toList(growable: false);
  }
  final keywords = switch (selectedFilter) {
    'Горы' => const ['гор', 'петри', 'бахчисар', 'кале', 'скал'],
    'Еда' => const ['еда', 'кухн', 'вин', 'сыр', 'гастроном'],
    'Лес' => const ['лес', 'троп', 'сосн', 'заповед'],
    _ => const <String>[],
  };
  if (keywords.isEmpty) {
    return routes;
  }
  return routes
      .where((route) => _matchesKeywords(route, keywords))
      .toList(growable: false);
}

const _seaKeywords = ['море', 'морск', 'берег', 'фиолент', 'свет', 'бухт'];

bool _matchesKeywords(RouteSummary route, List<String> keywords) {
  final searchable = '${route.name} ${route.shortDescription ?? ''}'
      .toLowerCase();
  return keywords.any(searchable.contains);
}
