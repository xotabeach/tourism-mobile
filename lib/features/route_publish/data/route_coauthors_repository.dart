import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Who writes a route together and who already agreed (spec 11c D7).
class RouteCoauthorsInfo {
  const RouteCoauthorsInfo({
    required this.isOwner,
    required this.ownerConsented,
    required this.coauthors,
    this.ownerUserId,
  });

  final bool isOwner;
  final String? ownerUserId;
  final bool ownerConsented;

  /// Invited and joined co-authors.
  final List<RouteCoauthor> coauthors;

  bool get waitsForSomeone =>
      !ownerConsented || coauthors.any((coauthor) => !coauthor.consented);
}

abstract interface class RouteCoauthorsRepository {
  Future<RouteCoauthorsInfo> load(String routeId);

  /// The owner's choice; the list replaces the previous one.
  Future<List<RouteCoauthor>> set(String routeId, List<String> userIds);

  /// A co-author declines or steps out.
  Future<void> leave(String routeId);
}

class ApiRouteCoauthorsRepository implements RouteCoauthorsRepository {
  ApiRouteCoauthorsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteCoauthorsInfo> load(String routeId) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/routes/$routeId/editable',
    );
    final json = response.data!;
    return RouteCoauthorsInfo(
      isOwner: (json['my_role'] as String? ?? 'owner') == 'owner',
      ownerUserId: json['owner_user_id'] as String?,
      ownerConsented: json['owner_consented'] as bool? ?? false,
      coauthors: RouteCoauthor.listFrom(json['coauthors']),
    );
  });

  @override
  Future<List<RouteCoauthor>> set(String routeId, List<String> userIds) =>
      guardApiCall(() async {
        final response = await _dio.put<List<dynamic>>(
          '/api/v1/routes/$routeId/coauthors',
          data: {'user_ids': userIds},
        );
        return RouteCoauthor.listFrom(response.data);
      });

  @override
  Future<void> leave(String routeId) => guardApiCall(() async {
    await _dio.delete<void>('/api/v1/routes/$routeId/coauthorship');
  });
}

/// Demo build and tests: a route nobody else writes yet.
class MockRouteCoauthorsRepository implements RouteCoauthorsRepository {
  final _chosen = <String, List<RouteCoauthor>>{};

  @override
  Future<RouteCoauthorsInfo> load(String routeId) async => RouteCoauthorsInfo(
    isOwner: true,
    ownerConsented: false,
    coauthors: _chosen[routeId] ?? const [],
  );

  @override
  Future<List<RouteCoauthor>> set(String routeId, List<String> userIds) async =>
      _chosen[routeId] = [
        for (final id in userIds)
          RouteCoauthor(userId: id, displayName: id, state: 'invited'),
      ];

  @override
  Future<void> leave(String routeId) async {}
}
