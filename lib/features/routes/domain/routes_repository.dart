import 'package:tourism_mobile/features/routes/domain/route.dart';

abstract interface class RoutesRepository {
  Future<RouteListPage> listRoutes({
    String? regionSlug,
    String? placeId,
    String? query,
    int limit = 50,
    int offset = 0,
    RouteCatalogSort sort = RouteCatalogSort.defaultOrder,
  });

  Future<RouteListPage> listMyRoutes();

  Future<RouteDetail> getRoute(String id);

  Future<RouteDetail> getMyRoute(String id);
}
