import 'package:tourism_mobile/features/routes/domain/route.dart';

const routeCatalogFilters = ['Все', 'Море', 'Горы', 'Еда', 'Лес'];

List<RouteSummary> filterRouteCatalog(
  List<RouteSummary> routes,
  String selectedFilter,
) {
  if (selectedFilter == 'Все') {
    return routes;
  }
  final keywords = switch (selectedFilter) {
    'Море' => const ['море', 'морск', 'берег', 'фиолент', 'свет', 'бухт'],
    'Горы' => const ['гор', 'петри', 'бахчисар', 'кале', 'скал'],
    'Еда' => const ['еда', 'кухн', 'вин', 'сыр', 'гастроном'],
    'Лес' => const ['лес', 'троп', 'сосн', 'заповед'],
    _ => const <String>[],
  };
  if (keywords.isEmpty) {
    return routes;
  }
  return routes
      .where((route) {
        final searchable = '${route.name} ${route.shortDescription ?? ''}'
            .toLowerCase();
        return keywords.any(searchable.contains);
      })
      .toList(growable: false);
}
