import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/routes/data/api_routes_repository.dart';
import 'package:tourism_mobile/features/routes/data/mock_routes_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockRoutesRepository();
  }
  return ApiRoutesRepository(ref.watch(dioProvider));
});

final routesListProvider = FutureProvider<RouteListPage>((ref) {
  return ref.watch(routesRepositoryProvider).listRoutes(regionSlug: 'crimea');
});

final routeDetailProvider = FutureProvider.autoDispose
    .family<RouteDetail, String>((ref, id) {
      return ref.watch(routesRepositoryProvider).getRoute(id);
    });
