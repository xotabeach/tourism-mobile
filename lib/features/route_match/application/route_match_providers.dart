import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/route_match/data/route_match_repository.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';

final routeMatchRepositoryProvider = Provider<RouteMatchRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockRouteMatchRepository();
  }
  return ApiRouteMatchRepository(ref.watch(dioProvider));
});

final lastRouteMatchResultProvider = StateProvider<RouteMatchResult?>(
  (ref) => null,
);

final lastRouteMatchParamsProvider = StateProvider<RouteMatchParams?>(
  (ref) => null,
);

/// Past chat sessions for the "История чатов" settings entry point.
final chatSessionsProvider = FutureProvider<RoutePlanningSessionListResult>((
  ref,
) {
  return ref.watch(routeMatchRepositoryProvider).listSessions(limit: 50);
});
