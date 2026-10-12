import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';

class ApiCompanionsRepository implements CompanionsRepository {
  ApiCompanionsRepository(this._dio);

  final Dio _dio;

  static const _base = '/api/v1/companion-groups';

  Future<CompanionGroup> _group(Future<Response<Map<String, dynamic>>> call) =>
      guardApiCall(() async => CompanionGroup.fromJson((await call).data!));

  @override
  Future<CompanionGroup> create(String routeId) =>
      _group(_dio.post(_base, data: {'route_id': routeId}));

  @override
  Future<List<CompanionGroup>> myGroups() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me/companion-groups',
    );
    return [
      for (final item in response.data?['items'] as List<dynamic>? ?? const [])
        CompanionGroup.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  });

  @override
  Future<CompanionGroup> get(String groupId) =>
      _group(_dio.get('$_base/$groupId'));

  @override
  Future<CompanionProgress> progress(String groupId) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/$groupId/progress',
    );
    return CompanionProgress.fromJson(response.data!);
  });

  @override
  Future<List<InvitablePerson>> invitable() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/invitable',
    );
    return [
      for (final item in response.data?['items'] as List<dynamic>? ?? const [])
        InvitablePerson.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  });

  @override
  Future<CompanionGroup> invite(String groupId, String userId) =>
      _group(_dio.post('$_base/$groupId/invites', data: {'user_id': userId}));

  @override
  Future<CompanionGroup> respond(String groupId, {required bool accept}) =>
      _group(_dio.post('$_base/$groupId/${accept ? 'accept' : 'decline'}'));

  @override
  Future<CompanionGroup> joinByCode(String code) =>
      _group(_dio.post('$_base/join', data: {'code': code}));

  @override
  Future<CompanionGroup> answerRequest(
    String groupId,
    String userId, {
    required bool approve,
  }) => _group(
    _dio.post(
      '$_base/$groupId/requests/$userId/${approve ? 'approve' : 'reject'}',
    ),
  );

  @override
  Future<CompanionGroup?> removeMember(String groupId, String userId) =>
      guardApiCall(() async {
        final response = await _dio.delete<Map<String, dynamic>>(
          '$_base/$groupId/members/$userId',
        );
        final data = response.data;
        return data == null || data.isEmpty
            ? null
            : CompanionGroup.fromJson(data);
      });

  @override
  Future<CompanionGroup> cancel(String groupId) =>
      _group(_dio.post('$_base/$groupId/cancel'));

  @override
  Future<CompanionGroup> setReady(String groupId, {required bool ready}) =>
      _group(_dio.post('$_base/$groupId/ready', data: {'ready': ready}));

  @override
  Future<CompanionGroup> start(String groupId) =>
      _group(_dio.post('$_base/$groupId/start'));

  @override
  Future<void> report(
    String groupId, {
    required String reason,
    String? comment,
  }) => guardApiCall(() async {
    await _dio.post<void>(
      '$_base/$groupId/report',
      data: {'reason': reason, 'comment': ?comment},
    );
  });
}
