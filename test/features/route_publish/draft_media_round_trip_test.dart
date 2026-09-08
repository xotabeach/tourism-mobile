import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/data/api_route_publication_repository.dart';

/// A draft's photos live on the server, and the editor that reopens one holds
/// none of the files. It therefore has to say "keep these" rather than
/// re-upload — otherwise saving a resumed draft archives every photo it just
/// showed (reported 2026-09-08).
final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  /// Path -> body, keyed by `'<METHOD> <path>'`.
  final Map<String, Object?> responses;
  final List<RequestOptions> requests = [];

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
  const editable = {
    'id': 'route-1',
    'publication_status': 'draft',
    'name': 'Черновик',
    'description': '',
    'places': [
      {
        'id': 'place-a',
        'name': 'Начало',
        'subtitle': 'Крым',
        'lat': 44.5,
        'lng': 34.1,
      },
      {
        'id': 'place-b',
        'name': 'Финиш',
        'subtitle': 'Крым',
        'lat': 44.6,
        'lng': 34.2,
      },
    ],
    'filters': <String>[],
    'pace': 'calm',
    'difficulty': 3,
    'media': [
      {
        'id': 'media-1',
        'public_path': '/media/routes/route-1/a.webp',
        'kind': 'image',
        'position': 0,
      },
      {
        'id': 'media-2',
        'public_path': '/media/routes/route-1/b.webp',
        'kind': 'image',
        'position': 1,
      },
    ],
    'updated_at': '2026-09-08T10:00:00Z',
  };

  test('a draft reopened from the server carries its photos', () async {
    final adapter = _RecordingAdapter({
      'GET /api/v1/routes/route-1/editable': editable,
    });
    final repository = ApiRoutePublicationRepository(
      Dio()..httpClientAdapter = adapter,
    );

    final draft = await repository.loadForEdit('route-1');

    expect(draft.media.map((item) => item.id), ['media-1', 'media-2']);
    expect(draft.media.first.path, '/media/routes/route-1/a.webp');
    // Marked remote, so the editor renders them over the network and the
    // media store does not go looking for them on this device.
    expect(draft.media.every((item) => item.isRemote), isTrue);
    expect(draft.media.every((item) => item.isAsset), isFalse);
  });

  test('saving that draft keeps its photos instead of deleting them', () async {
    final adapter = _RecordingAdapter({
      'GET /api/v1/routes/route-1/editable': editable,
      'POST /api/v1/routes/drafts': {
        'id': 'route-1',
        'publication_status': 'draft',
        'updated_at': '2026-09-08T10:05:00Z',
      },
    });
    final repository = ApiRoutePublicationRepository(
      Dio()..httpClientAdapter = adapter,
    );

    final draft = await repository.loadForEdit('route-1');
    await repository.saveDraft(draft);

    final sync = adapter.requests.singleWhere(
      (request) =>
          request.method == 'PUT' &&
          request.path == '/api/v1/routes/drafts/route-1/media',
    );
    expect((sync.data! as Map)['keep'], ['media-1', 'media-2']);
    // Nothing to upload: the bytes were never on this device.
    expect(
      adapter.requests.any(
        (request) =>
            request.method == 'POST' &&
            request.path == '/api/v1/routes/drafts/route-1/media',
      ),
      isFalse,
    );
    // And the old clear-everything call is gone.
    expect(
      adapter.requests.any((request) => request.method == 'DELETE'),
      isFalse,
    );
  });

  test('a photo removed in the editor drops out of the kept list', () async {
    final adapter = _RecordingAdapter({
      'GET /api/v1/routes/route-1/editable': editable,
      'POST /api/v1/routes/drafts': {
        'id': 'route-1',
        'publication_status': 'draft',
        'updated_at': '2026-09-08T10:05:00Z',
      },
    });
    final repository = ApiRoutePublicationRepository(
      Dio()..httpClientAdapter = adapter,
    );

    final draft = await repository.loadForEdit('route-1');
    await repository.saveDraft(
      draft.copyWith(media: [draft.media.last, draft.media.first]),
    );

    final sync = adapter.requests.singleWhere(
      (request) => request.method == 'PUT',
    );
    expect((sync.data! as Map)['keep'], ['media-2', 'media-1']);
  });

  test('a draft with no photos left clears the gallery', () async {
    final adapter = _RecordingAdapter({
      'GET /api/v1/routes/route-1/editable': editable,
      'POST /api/v1/routes/drafts': {
        'id': 'route-1',
        'publication_status': 'draft',
        'updated_at': '2026-09-08T10:05:00Z',
      },
    });
    final repository = ApiRoutePublicationRepository(
      Dio()..httpClientAdapter = adapter,
    );

    final draft = await repository.loadForEdit('route-1');
    await repository.saveDraft(draft.copyWith(media: const []));

    final sync = adapter.requests.singleWhere(
      (request) => request.method == 'PUT',
    );
    expect((sync.data! as Map)['keep'], isEmpty);
  });
}
