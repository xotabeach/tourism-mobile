import 'package:dio/dio.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

final class ApiRoutePublicationRepository
    implements RoutePublicationRepository {
  ApiRoutePublicationRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> discardDraft(String routeId) {
    return guardApiCall(() async {
      await _dio.delete<void>('/api/v1/routes/drafts/$routeId');
    });
  }

  @override
  Future<RouteDraft> loadForEdit(String routeId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/editable',
      );
      return _draftFromJson(response.data!);
    });
  }

  /// Rebuilds the editor draft from the server payload.
  ///
  /// `place_ids` is sent flattened as start + stops + finish (see [_payload]),
  /// so it is unflattened the same way here. A two-stop route is start and
  /// finish with nothing between them.
  RouteDraft _draftFromJson(Map<String, dynamic> json) {
    final places = (json['places'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (item) => RouteLocation(
            id: item['id'] as String,
            name: item['name'] as String? ?? '',
            subtitle: item['subtitle'] as String? ?? '',
            lat: (item['lat'] as num?)?.toDouble() ?? 0,
            lng: (item['lng'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
    final middle = places.length > 2
        ? places.sublist(1, places.length - 1)
        : const <RouteLocation>[];
    return RouteDraft(
      serverId: json['id'] as String,
      publicationStatus: RoutePublicationStatus.fromApi(
        json['publication_status'] as String?,
      ),
      title: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      start: places.isNotEmpty ? places.first : null,
      finish: places.length > 1 ? places.last : null,
      stops: [
        for (final place in middle) RouteStopDraft(location: place),
      ],
      filters: (json['filters'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      pace: TravelPace.values.firstWhere(
        (value) => value.name == json['pace'],
        orElse: () => TravelPace.calm,
      ),
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc(),
    );
  }

  @override
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/routes/drafts',
        data: _payload(draft),
      );
      return _receipt(response.data!);
    });
  }

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) {
    return guardApiCall(() async {
      final routeId = draft.serverId;
      if (routeId == null || routeId.isEmpty) {
        throw StateError('Route draft must be saved before submission');
      }
      await _dio.delete<void>('/api/v1/routes/drafts/$routeId/media');
      for (var index = 0; index < draft.media.length; index++) {
        final media = draft.media[index];
        if (media.isAsset) {
          continue;
        }
        await _dio.post<Map<String, dynamic>>(
          '/api/v1/routes/drafts/$routeId/media',
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(media.path),
            'position': index,
          }),
        );
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/submit',
      );
      return _receipt(response.data!);
    });
  }

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/routes/$routeId/withdraw',
      );
      return _receipt(response.data!);
    });
  }

  Map<String, Object?> _payload(RouteDraft draft) {
    return {
      'route_id': draft.serverId,
      'name': draft.title.trim(),
      'description': draft.description.trim(),
      'place_ids': [
        if (draft.start != null) draft.start!.id,
        ...draft.stops.map((stop) => stop.location.id),
        if (draft.finish != null) draft.finish!.id,
      ],
      'filters': draft.filters,
      'pace': draft.pace.name,
      'difficulty': draft.difficulty,
    };
  }

  RoutePublicationReceipt _receipt(Map<String, dynamic> json) {
    return RoutePublicationReceipt(
      id: json['id'] as String,
      status: RoutePublicationStatus.fromApi(
        json['publication_status'] as String?,
      ),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }
}

final class InMemoryRoutePublicationRepository
    implements RoutePublicationRepository {
  const InMemoryRoutePublicationRepository();

  @override
  Future<void> discardDraft(String routeId) async {}

  @override
  Future<RouteDraft> loadForEdit(String routeId) async {
    // Mock mode has no server copy; the local draft is the only one there is.
    return RouteDraft(serverId: routeId);
  }

  @override
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft) async {
    return RoutePublicationReceipt(
      id:
          draft.serverId ??
          'local-route-${DateTime.now().microsecondsSinceEpoch}',
      status: RoutePublicationStatus.draft,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) async {
    return RoutePublicationReceipt(
      id: draft.serverId!,
      status: RoutePublicationStatus.pendingReview,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) async {
    return RoutePublicationReceipt(
      id: routeId,
      status: RoutePublicationStatus.draft,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
