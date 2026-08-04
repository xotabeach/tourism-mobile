import 'package:dio/dio.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

final class ApiRoutePublicationRepository
    implements RoutePublicationRepository {
  ApiRoutePublicationRepository(this._dio);

  final Dio _dio;

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
}
