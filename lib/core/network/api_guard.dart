import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';

Future<T> guardApiCall<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AppFailure {
    rethrow;
  } on DioException catch (error, stackTrace) {
    Error.throwWithStackTrace(_mapDioFailure(error), stackTrace);
  } on Object catch (_, stackTrace) {
    Error.throwWithStackTrace(const UnexpectedFailure(), stackTrace);
  }
}

AppFailure _mapDioFailure(DioException error) {
  final status = error.response?.statusCode;
  final apiMessage = _apiErrorMessage(error);
  final apiCode = _apiErrorCode(error);
  if (status == 403 && apiCode == 'route_start_blocked') {
    return RouteStartBlockedFailure(
      _blockedUntil(error),
      apiMessage ?? 'Route start is temporarily unavailable',
    );
  }
  if (status == 401 || status == 403) {
    return AuthFailure(apiMessage ?? 'Authentication failed', apiCode);
  }
  if (status == 404) {
    return NotFoundFailure(apiMessage ?? 'Resource not found', apiCode);
  }
  if (_isFinalRejection(error)) {
    return RejectedFailure(apiMessage ?? 'Request rejected', apiCode);
  }
  if (status != null && status >= 400 && status < 500 && apiMessage != null) {
    return UnexpectedFailure(apiMessage, apiCode);
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.cancel => const NetworkFailure(),
    DioExceptionType.badCertificate ||
    DioExceptionType.badResponse ||
    DioExceptionType.unknown => UnexpectedFailure(
      apiMessage ?? 'Unexpected error',
    ),
  };
}

DateTime? _blockedUntil(DioException error) {
  final data = error.response?.data;
  if (data is! Map) {
    return null;
  }
  final envelope = data['error'];
  final details = envelope is Map ? envelope['details'] : null;
  final raw = details is Map ? details['blocked_until'] : null;
  return raw is String ? DateTime.tryParse(raw) : null;
}

/// True when the API states that repeating this request cannot help.
bool _isFinalRejection(DioException error) {
  final status = error.response?.statusCode;
  if (status != 409 && status != 422) {
    return false;
  }
  final data = error.response?.data;
  if (data is! Map) {
    return false;
  }
  final envelope = data['error'];
  if (envelope is! Map) {
    return false;
  }
  final details = envelope['details'];
  return details is Map && details['retryable'] == false;
}

/// The envelope's machine-readable `error.code`, when there is one.
String? _apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map) {
    return null;
  }
  final envelope = data['error'];
  if (envelope is! Map) {
    return null;
  }
  final code = envelope['code'];
  return code is String && code.isNotEmpty && code.length <= 64 ? code : null;
}

/// Controlled API envelope message only — never request paths or raw bodies.
String? _apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map) {
    return null;
  }
  final envelope = data['error'];
  if (envelope is! Map) {
    return null;
  }
  final message = envelope['message'];
  if (message is! String) {
    return null;
  }
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 300) {
    return null;
  }
  return trimmed;
}
