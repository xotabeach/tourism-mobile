import 'package:tourism_mobile/features/routes/domain/route.dart';

abstract interface class RoutesRepository {
  Future<RouteListPage> listRoutes({String? regionSlug});

  Future<RouteListPage> listMyRoutes();

  Future<RouteDetail> getRoute(String id);
}
