import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';

final class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> requestOtp({
    required String displayName,
    required String phone,
  }) {
    return guardApiCall(() async {
      await _dio.post<void>(
        '/api/v1/auth/otp/request',
        data: {'display_name': displayName, 'phone': phone},
      );
    });
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/verify',
        data: {
          'phone': phone,
          'code': code,
          'privacy_accepted': privacyAccepted,
          'personal_data_accepted': personalDataAccepted,
        },
      );
      return _tokensFrom(response.data);
    });
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _tokensFrom(response.data);
    });
  }

  @override
  Future<void> logout(String refreshToken) {
    return guardApiCall(() async {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    });
  }

  @override
  Future<MeProfile> getMe(String accessToken) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }

  @override
  Future<MeProfile> patchMe({
    required String accessToken,
    required String displayName,
  }) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/me',
        data: {'display_name': displayName},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }

  AuthTokens _tokensFrom(Map<String, dynamic>? data) {
    if (data == null) {
      throw const UnexpectedFailure();
    }
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    final expiresIn = data['expires_in'];
    if (access is! String || refresh is! String || expiresIn is! int) {
      throw const UnexpectedFailure();
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: expiresIn,
    );
  }

  MeProfile _meFrom(Map<String, dynamic>? data) {
    if (data == null) {
      throw const UnexpectedFailure();
    }
    final id = data['id'];
    final name = data['display_name'];
    final phone = data['phone'];
    if (id is! String || name is! String || phone is! String) {
      throw const UnexpectedFailure();
    }
    return MeProfile(id: id, displayName: name, phone: phone);
  }
}

final class MockAuthRepository implements AuthRepository {
  @override
  Future<void> requestOtp({
    required String displayName,
    required String phone,
  }) async {}

  @override
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) async {
    if (!privacyAccepted || !personalDataAccepted) {
      throw const AuthFailure('Consents required');
    }
    return const AuthTokens(
      accessToken: 'mock-access',
      refreshToken: 'mock-refresh',
      expiresIn: 900,
    );
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    return AuthTokens(
      accessToken: 'mock-access-refreshed',
      refreshToken: refreshToken,
      expiresIn: 900,
    );
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<MeProfile> getMe(String accessToken) async {
    return const MeProfile(
      id: 'mock-user',
      displayName: 'Путешественник',
      phone: '+79000000000',
    );
  }

  @override
  Future<MeProfile> patchMe({
    required String accessToken,
    required String displayName,
  }) async {
    return MeProfile(
      id: 'mock-user',
      displayName: displayName,
      phone: '+79000000000',
    );
  }
}
