import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

void main() {
  test('404 maps to a safe not-found failure', () async {
    final options = RequestOptions(path: '/private/resource');

    await expectLater(
      guardApiCall<void>(
        () => throw DioException(
          requestOptions: options,
          response: Response<void>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      ),
      throwsA(
        isA<NotFoundFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains('/private/resource')),
        ),
      ),
    );
  });

  test('transport details map to a generic network failure', () async {
    const secretUrl = 'https://secret.internal.example/token';

    await expectLater(
      guardApiCall<void>(
        () => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: RequestOptions(path: secretUrl),
        ),
      ),
      throwsA(
        isA<NetworkFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains(secretUrl)),
        ),
      ),
    );
  });

  test('decoding errors map to a generic unexpected failure', () async {
    await expectLater(
      guardApiCall<void>(() => throw const FormatException('secret payload')),
      throwsA(
        isA<UnexpectedFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains('secret payload')),
        ),
      ),
    );
  });
}
