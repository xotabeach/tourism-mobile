import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

abstract interface class DeviceTokenRepository {
  Future<void> register({required String token, required String platform});
  Future<void> unregister(String token);
}

final class ApiDeviceTokenRepository implements DeviceTokenRepository {
  ApiDeviceTokenRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> register({required String token, required String platform}) {
    return guardApiCall(() async {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/device-tokens',
        data: {'token': token, 'platform': platform},
      );
    });
  }

  @override
  Future<void> unregister(String token) {
    return guardApiCall(() async {
      await _dio.delete<void>(
        '/api/v1/me/device-tokens',
        data: {'token': token},
      );
    });
  }
}

final class NoopDeviceTokenRepository implements DeviceTokenRepository {
  @override
  Future<void> register({required String token, required String platform}) async {}

  @override
  Future<void> unregister(String token) async {}
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return NoopDeviceTokenRepository();
  }
  return ApiDeviceTokenRepository(ref.watch(dioProvider));
});
