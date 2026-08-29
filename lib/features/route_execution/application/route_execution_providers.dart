import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/data/api_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/mock_route_execution_repository.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution_repository.dart';

final routeExecutionRepositoryProvider = Provider<RouteExecutionRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockData) {
    return MockRouteExecutionRepository();
  }
  return ApiRouteExecutionRepository(ref.watch(dioProvider));
});

final activeRouteExecutionProvider =
    FutureProvider.autoDispose<RouteExecution?>(
      (ref) => ref.watch(routeExecutionRepositoryProvider).getActive(),
    );

final routeExecutionOfflineStoreProvider = Provider<RouteExecutionOfflineStore>(
  (ref) {
    return SecureRouteExecutionOfflineStore(ref.watch(secureStorageProvider));
  },
);

final routeExecutionOfflineCoordinatorProvider =
    Provider<RouteExecutionOfflineCoordinator>((ref) {
      return RouteExecutionOfflineCoordinator(
        ref.watch(routeExecutionOfflineStoreProvider),
        ref.watch(routeExecutionRepositoryProvider),
      );
    });

final routeExecutionHistoryProvider =
    FutureProvider.autoDispose<List<RouteExecution>>(
      (ref) => ref.watch(routeExecutionRepositoryProvider).list(),
    );
