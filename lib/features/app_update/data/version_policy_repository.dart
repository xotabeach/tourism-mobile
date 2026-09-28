import 'package:dio/dio.dart';

import 'package:tourism_mobile/features/app_update/domain/version_policy.dart';

abstract interface class VersionPolicyRepository {
  Future<VersionPolicy> fetch();
}

/// The build itself travels in `X-App-Version` (see app_version_headers).
final class ApiVersionPolicyRepository implements VersionPolicyRepository {
  ApiVersionPolicyRepository(this._dio);

  final Dio _dio;

  @override
  Future<VersionPolicy> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/app/version-policy',
      queryParameters: const {'platform': 'android'},
    );
    final data = response.data;
    return data == null ? VersionPolicy.none : VersionPolicy.fromJson(data);
  }
}

/// Mock data mode and tests: never prompts.
final class NoUpdateVersionPolicyRepository implements VersionPolicyRepository {
  const NoUpdateVersionPolicyRepository();

  @override
  Future<VersionPolicy> fetch() async => VersionPolicy.none;
}
