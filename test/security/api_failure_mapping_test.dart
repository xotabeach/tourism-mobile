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

  test('API envelope message is surfaced without leaking paths', () async {
    final options = RequestOptions(path: '/api/v1/routes/secret-id/reviews');

    await expectLater(
      guardApiCall<void>(
        () => throw DioException(
          requestOptions: options,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 409,
            data: const {
              'error': {
                'code': 'route_not_published',
                'message':
                    'Нельзя оставлять отзывы на неопубликованные маршруты',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
      throwsA(
        isA<UnexpectedFailure>()
            .having(
              (failure) => failure.message,
              'api message',
              'Нельзя оставлять отзывы на неопубликованные маршруты',
            )
            .having(
              (failure) => failure.toString(),
              'safe message',
              isNot(contains('secret-id')),
            ),
      ),
    );
  });

  test('a final rejection is distinguishable from a retryable error', () async {
    final options = RequestOptions(
      path: '/api/v1/route-executions/secret/cancel',
    );

    await expectLater(
      guardApiCall<void>(
        () => throw DioException(
          requestOptions: options,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 409,
            data: const {
              'error': {
                'code': 'route_execution_not_active',
                'message': 'Route execution is not active',
                'details': {'status': 'completed', 'retryable': false},
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
      throwsA(
        isA<RejectedFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains('secret')),
        ),
      ),
    );
  });

  test('a conflict without a verdict stays retryable', () async {
    final options = RequestOptions(path: '/api/v1/route-executions');

    await expectLater(
      guardApiCall<void>(
        () => throw DioException(
          requestOptions: options,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 409,
            data: const {
              'error': {
                'code': 'active_route_execution_exists',
                'message': 'Finish or cancel the active route first',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
      throwsA(isA<UnexpectedFailure>()),
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
