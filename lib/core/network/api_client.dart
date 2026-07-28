import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

/// Dio without auth interceptors (used by auth repository itself).
final rawDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  );
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(sessionProvider).accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isAuthPath =
            path.contains('/auth/otp/') ||
            path.contains('/auth/refresh') ||
            path.contains('/auth/logout');
        if (status != 401 || isAuthPath) {
          handler.next(error);
          return;
        }
        final fresh = await ref
            .read(sessionProvider.notifier)
            .refreshAccessToken();
        if (fresh == null) {
          handler.next(error);
          return;
        }
        final request = error.requestOptions;
        request.headers['Authorization'] = 'Bearer $fresh';
        try {
          final response = await dio.fetch<dynamic>(request);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ),
  );
  return dio;
});
