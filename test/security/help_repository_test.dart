import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/settings/data/help_repository.dart';

const _article = HelpArticle(
  id: 'points-earn',
  revision: 1,
  appVersion: '0.2.31',
  title: 'Баллы',
  excerpt: 'Текст',
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, Object?> response = {
    'available': true,
    'method': 'full_text',
    'items': [],
  };
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'support question goes in the body, not access-log query strings',
    () async {
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = ApiHelpRepository(dio, () async => '0.2.31');
      final result = await repo.search('Мой личный вопрос');
      expect(result.available, isTrue);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(adapter.requests.single.data, {
        'q': 'Мой личный вопрос',
        'app_version': '0.2.31',
      });
    },
  );

  test(
    'detail uses the selected edition and rejects substituted source IDs',
    () async {
      final adapter = _Adapter()
        ..response = {
          'article_id': 'different-source',
          'revision': 1,
          'app_version': '0.2.31',
          'title': 'Баллы',
          'excerpt': 'Текст',
          'body': 'Полный текст',
        };
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = ApiHelpRepository(dio, () async => '99.0.0');
      await expectLater(repo.read(_article), throwsA(isA<UnexpectedFailure>()));
      expect(adapter.requests.single.queryParameters, {
        'revision': 1,
        'app_version': '0.2.31',
      });
      expect(adapter.requests.single.path, '/api/v1/support/help/points-earn');
    },
  );

  test(
    'withdrawn source stays unavailable with no bundled-text fallback',
    () async {
      final adapter = _Adapter()
        ..statusCode = 404
        ..response = {
          'error': {
            'code': 'help_article_unavailable',
            'message': 'Статья недоступна',
          },
        };
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = ApiHelpRepository(dio, () async => '0.2.31');
      await expectLater(repo.read(_article), throwsA(isA<NotFoundFailure>()));
      expect(adapter.requests, hasLength(1));
    },
  );
}
