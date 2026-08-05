import 'package:tourism_mobile/features/routes/domain/route.dart';

abstract interface class RoutesRepository {
  Future<RouteListPage> listRoutes({
    String? regionSlug,
    String? query,
    int limit = 50,
    RouteCatalogSort sort = RouteCatalogSort.defaultOrder,
  });

  Future<RouteListPage> listMyRoutes();

  Future<RouteDetail> getRoute(String id);

  Future<RouteDetail> getMyRoute(String id);
}
