import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';

/// Who may invite me to a group or to co-author a route (spec 11b, D15).
enum InvitePolicy {
  /// People I follow who follow me back.
  mutual,

  /// Nobody: invitations are closed.
  nobody;

  static InvitePolicy parse(Object? value) =>
      value == 'nobody' ? nobody : mutual;

  String get api => name;
}

/// Someone I blocked: no invitations and no shared groups, both ways.
class BlockedPerson {
  const BlockedPerson({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;

  factory BlockedPerson.fromJson(Map<String, dynamic> json) => BlockedPerson(
    userId: json['id'] as String,
    displayName: json['display_name'] as String? ?? 'Путешественник',
    avatarUrl: json['avatar_url'] as String?,
  );
}

abstract interface class InvitePrivacyRepository {
  Future<InvitePolicy> policy();

  Future<void> setPolicy(InvitePolicy policy);

  Future<List<BlockedPerson>> blocked();

  Future<void> block(String userId);

  Future<void> unblock(String userId);
}

class ApiInvitePrivacyRepository implements InvitePrivacyRepository {
  ApiInvitePrivacyRepository(this._dio);

  final Dio _dio;

  @override
  Future<InvitePolicy> policy() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/me');
    return InvitePolicy.parse(response.data?['invite_policy']);
  });

  @override
  Future<void> setPolicy(InvitePolicy policy) => guardApiCall(() async {
    await _dio.patch<void>('/api/v1/me', data: {'invite_policy': policy.api});
  });

  @override
  Future<List<BlockedPerson>> blocked() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/blocked',
    );
    return [
      for (final item in response.data?['items'] as List<dynamic>? ?? const [])
        BlockedPerson.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  });

  @override
  Future<void> block(String userId) => guardApiCall(() async {
    await _dio.put<void>('/api/v1/users/$userId/block');
  });

  @override
  Future<void> unblock(String userId) => guardApiCall(() async {
    await _dio.delete<void>('/api/v1/users/$userId/block');
  });
}

/// The demo build: kept in memory.
class MockInvitePrivacyRepository implements InvitePrivacyRepository {
  var _policy = InvitePolicy.mutual;
  final _blocked = <String, BlockedPerson>{};

  @override
  Future<InvitePolicy> policy() async => _policy;

  @override
  Future<void> setPolicy(InvitePolicy policy) async => _policy = policy;

  @override
  Future<List<BlockedPerson>> blocked() async => _blocked.values.toList();

  @override
  Future<void> block(String userId) async => _blocked[userId] = BlockedPerson(
    userId: userId,
    displayName: 'Путешественник',
  );

  @override
  Future<void> unblock(String userId) async => _blocked.remove(userId);
}
