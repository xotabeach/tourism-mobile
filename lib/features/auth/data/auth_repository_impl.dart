import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';

final class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<OtpStartResult> requestOtp({
    required String phone,
    String? displayName,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/start',
        data: {'display_name': ?displayName, 'phone': phone},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return OtpStartResult(
        registrationRequired: data['registration_required'] as bool? ?? false,
        consentsRequired: data['consents_required'] as bool? ?? true,
        otpSent: data['otp_sent'] as bool? ?? false,
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
    String? displayName,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  }) {
    return guardApiCall(() async {
      final data = <String, dynamic>{
        'display_name': ?displayName,
        'notify_push_enabled': ?notifyPushEnabled,
        'notify_sms_enabled': ?notifySmsEnabled,
        'notify_haptics_enabled': ?notifyHapticsEnabled,
      };
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/me',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }

  @override
  Future<void> requestPhoneChange({
    required String accessToken,
    required String phone,
  }) {
    return guardApiCall(() async {
      await _dio.post<void>(
        '/api/v1/me/phone/otp/request',
        data: {'phone': phone},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    });
  }

  @override
  Future<MeProfile> verifyPhoneChange({
    required String accessToken,
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/phone/otp/verify',
        data: {
          'phone': phone,
          'code': code,
          'privacy_accepted': privacyAccepted,
          'personal_data_accepted': personalDataAccepted,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }

  @override
  Future<MeProfile> uploadAvatar({
    required String accessToken,
    required String filePath,
  }) {
    return _uploadMedia(
      accessToken: accessToken,
      path: '/api/v1/me/avatar',
      filePath: filePath,
    );
  }

  @override
  Future<MeProfile> uploadCover({
    required String accessToken,
    required String filePath,
  }) {
    return _uploadMedia(
      accessToken: accessToken,
      path: '/api/v1/me/cover',
      filePath: filePath,
    );
  }

  Future<MeProfile> _uploadMedia({
    required String accessToken,
    required String path,
    required String filePath,
  }) {
    return guardApiCall(() async {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: form,
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
    final avatar = data['avatar_url'];
    final cover = data['cover_url'];
    return MeProfile(
      id: id,
      displayName: name,
      phone: phone,
      avatarUrl: avatar is String ? avatar : null,
      coverUrl: cover is String ? cover : null,
      notifyPushEnabled: data['notify_push_enabled'] as bool? ?? true,
      notifySmsEnabled: data['notify_sms_enabled'] as bool? ?? false,
      notifyHapticsEnabled: data['notify_haptics_enabled'] as bool? ?? true,
      travelPlusActive: data['travel_plus_active'] as bool? ?? false,
      travelPlusPlan: data['travel_plus_plan'] as String?,
      travelPlusExpiresAt: _parseIsoDate(data['travel_plus_expires_at']),
      aiChatEnabled: data['ai_chat_enabled'] as bool? ?? false,
      maxRoutePoints: data['max_route_points'] as int? ?? 5,
      alternativesCount: data['alternatives_count'] as int? ?? 1,
      advancedFiltersEnabled:
          data['advanced_filters_enabled'] as bool? ?? false,
    );
  }

  DateTime? _parseIsoDate(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Future<MeProfile> activateTravelPlus({
    required String accessToken,
    required String plan,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/travel-plus/activate',
        data: {'plan': plan},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }

  @override
  Future<MeProfile> cancelTravelPlus({required String accessToken}) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/travel-plus/cancel',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _meFrom(response.data);
    });
  }
}

final class MockAuthRepository implements AuthRepository {
  String _displayName = 'Путешественник';
  String _phone = '+79000000000';
  String? _avatarUrl;
  String? _coverUrl;
  bool _notifyPushEnabled = true;
  bool _notifySmsEnabled = false;
  bool _notifyHapticsEnabled = true;
  bool _travelPlusActive = false;
  String? _travelPlusPlan;
  DateTime? _travelPlusExpiresAt;

  @override
  Future<OtpStartResult> requestOtp({
    required String phone,
    String? displayName,
  }) async {
    const existingDemoPhone = '+79990000000';
    if (phone == existingDemoPhone) {
      _phone = phone;
      _displayName = 'Никита Можаров';
      return const OtpStartResult(
        registrationRequired: false,
        consentsRequired: false,
        otpSent: true,
      );
    }
    if (displayName == null || displayName.trim().isEmpty) {
      return const OtpStartResult(
        registrationRequired: true,
        consentsRequired: true,
        otpSent: false,
      );
    }
    _phone = phone;
    _displayName = displayName.trim();
    return const OtpStartResult(
      registrationRequired: false,
      consentsRequired: true,
      otpSent: true,
    );
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) async {
    if (_phone != '+79990000000' &&
        (!privacyAccepted || !personalDataAccepted)) {
      throw const AuthFailure('Consents required');
    }
    _phone = phone;
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
    return MeProfile(
      id: 'mock-user',
      displayName: _displayName,
      phone: _phone,
      avatarUrl: _avatarUrl,
      coverUrl: _coverUrl,
      notifyPushEnabled: _notifyPushEnabled,
      notifySmsEnabled: _notifySmsEnabled,
      notifyHapticsEnabled: _notifyHapticsEnabled,
      travelPlusActive: _travelPlusActive,
      travelPlusPlan: _travelPlusPlan,
      travelPlusExpiresAt: _travelPlusExpiresAt,
      aiChatEnabled: _travelPlusActive,
      maxRoutePoints: _travelPlusActive ? 12 : 5,
      alternativesCount: _travelPlusActive ? 3 : 1,
      advancedFiltersEnabled: _travelPlusActive,
    );
  }

  @override
  Future<MeProfile> patchMe({
    required String accessToken,
    String? displayName,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  }) async {
    if (displayName != null) {
      _displayName = displayName;
    }
    if (notifyPushEnabled != null) {
      _notifyPushEnabled = notifyPushEnabled;
    }
    if (notifySmsEnabled != null) {
      _notifySmsEnabled = notifySmsEnabled;
    }
    if (notifyHapticsEnabled != null) {
      _notifyHapticsEnabled = notifyHapticsEnabled;
    }
    return getMe(accessToken);
  }

  @override
  Future<void> requestPhoneChange({
    required String accessToken,
    required String phone,
  }) async {}

  @override
  Future<MeProfile> verifyPhoneChange({
    required String accessToken,
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) async {
    if (!privacyAccepted || !personalDataAccepted) {
      throw const AuthFailure('Consents required');
    }
    _phone = phone;
    return getMe(accessToken);
  }

  @override
  Future<MeProfile> uploadAvatar({
    required String accessToken,
    required String filePath,
  }) async {
    _avatarUrl = 'file://$filePath';
    return getMe(accessToken);
  }

  @override
  Future<MeProfile> uploadCover({
    required String accessToken,
    required String filePath,
  }) async {
    _coverUrl = 'file://$filePath';
    return getMe(accessToken);
  }

  @override
  Future<MeProfile> activateTravelPlus({
    required String accessToken,
    required String plan,
  }) async {
    final yearly = plan == 'yearly';
    _travelPlusActive = true;
    _travelPlusPlan = plan;
    _travelPlusExpiresAt = DateTime.now().add(
      Duration(days: yearly ? 365 : 30),
    );
    return getMe(accessToken);
  }

  @override
  Future<MeProfile> cancelTravelPlus({required String accessToken}) async {
    _travelPlusActive = false;
    _travelPlusPlan = null;
    _travelPlusExpiresAt = null;
    return getMe(accessToken);
  }
}
