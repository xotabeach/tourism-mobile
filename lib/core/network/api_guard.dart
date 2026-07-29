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
  if (status == 401 || status == 403) {
    return const AuthFailure();
  }
  if (status == 404) {
    return const NotFoundFailure();
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
    DioExceptionType.unknown => const UnexpectedFailure(),
  };
}
