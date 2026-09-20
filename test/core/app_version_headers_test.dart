import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/app_version_headers.dart';

import '../support/test_overrides.dart';

class _Capture extends Interceptor {
  Map<String, dynamic>? headers;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    headers = Map.of(options.headers);
    handler.resolve(Response<void>(requestOptions: options, statusCode: 200));
  }
}

Future<Map<String, dynamic>> _headersSent(Dio dio) async {
  final capture = _Capture();
  dio.interceptors.add(capture);
  await dio.get<void>('/ping');
  return capture.headers!;
}

void main() {
  for (final entry in {
    'dioProvider': dioProvider,
    'rawDioProvider': rawDioProvider,
  }.entries) {
    test('${entry.key} sends the app version and platform', () async {
      final container = ProviderContainer(
        overrides: [
          ...testSessionOverrides(),
          appVersionHeadersLoaderProvider.overrideWithValue(
            () async => {
              'X-App-Version': '0.2.6+12',
              'X-App-Platform': 'android',
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      final headers = await _headersSent(container.read(entry.value));
      expect(headers['X-App-Version'], '0.2.6+12');
      expect(headers['X-App-Platform'], 'android');
      expect(RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch('0.2.6+12'), isTrue);
    });
  }

  test('a failing loader never blocks a request', () async {
    final container = ProviderContainer(
      overrides: [
        ...testSessionOverrides(),
        appVersionHeadersLoaderProvider.overrideWithValue(() async => {}),
      ],
    );
    addTearDown(container.dispose);
    final headers = await _headersSent(container.read(rawDioProvider));
    expect(headers.containsKey('X-App-Version'), isFalse);
  });
}
