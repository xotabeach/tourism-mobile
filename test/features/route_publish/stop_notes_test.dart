import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/data/api_route_publication_repository.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

// BACKEND-44: the author's notes to points, and names past 30 characters.

RouteLocation _place(String id) =>
    RouteLocation(id: id, name: id, subtitle: '', lat: 44.5, lng: 34.1);

RouteDraft _draft(Map<String, String> notes) => RouteDraft(
  title: 'Маршрут',
  start: _place('start'),
  finish: _place('finish'),
  stops: [RouteStopDraft(location: _place('a'))],
  stopNotes: notes,
);

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);

  final Map<String, Object?> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = responses['${options.method} ${options.path}'];
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      body == null ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('only notes on points still on the route are sent, trimmed', () {
    final draft = _draft({'a': '  Вход платный  ', 'gone': 'x', 'start': ' '});
    expect(draft.validStopNotes, {'a': 'Вход платный'});
  });

  test('notes survive the device copy and count as an edit', () {
    final again = RouteDraft.fromJson(_draft({'a': 'Спуск'}).toJson());
    expect(again.stopNotes, {'a': 'Спуск'});
    expect(_draft({'a': 'Спуск'}).sameContentAs(_draft({})), isFalse);
    expect(
      _draft({'a': 'Спуск'}).sameContentAs(_draft({'a': 'Спуск', 'gone': 'x'})),
      isTrue,
    );
  });

  test('the server gets the notes and gives them back to the editor', () async {
    final adapter = _Adapter({
      'GET /api/v1/routes/route-1/editable': {
        'id': 'route-1',
        'publication_status': 'draft',
        'name': 'Ялта • Ай-Петри и горный серпантин до водопада Учан-Су',
        'description': '',
        'places': [
          {'id': 'start', 'name': 'Старт', 'lat': 44.5, 'lng': 34.1},
          {
            'id': 'finish',
            'name': 'Финиш',
            'lat': 44.6,
            'lng': 34.2,
            'note': 'Парковка платная',
          },
        ],
        'filters': <String>[],
        'pace': 'calm',
        'difficulty': 3,
        'updated_at': '2026-10-13T10:00:00Z',
      },
      'POST /api/v1/routes/drafts': {
        'id': 'route-1',
        'publication_status': 'draft',
        'updated_at': '2026-10-13T10:05:00Z',
      },
    });
    final repository = ApiRoutePublicationRepository(
      Dio()..httpClientAdapter = adapter,
    );

    final draft = await repository.loadForEdit('route-1');
    expect(draft.stopNotes, {'finish': 'Парковка платная'});
    expect(draft.title.length, greaterThan(30));
    expect(draft.title.length, lessThanOrEqualTo(routeNameMaxLength));

    await repository.saveDraft(draft);
    final sent =
        adapter.requests
                .singleWhere((r) => r.path == '/api/v1/routes/drafts')
                .data
            as Map<String, Object?>;
    expect(sent['stop_notes'], {'finish': 'Парковка платная'});
  });
}
