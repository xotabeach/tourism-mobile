import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

abstract interface class RouteDraftRepository {
  Future<RouteDraft?> load();

  Future<void> save(RouteDraft draft);

  Future<void> delete();
}

abstract interface class RoutePublicationRepository {
  /// Own route pulled back from the server in editor shape.
  ///
  /// The local draft only exists on the device that started it, so without
  /// this an author could not resume editing anywhere else — the app said
  /// as much and stopped there (reported 2026-09-04).
  Future<RouteDraft> loadForEdit(String routeId);

  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft);

  Future<RoutePublicationReceipt> submit(RouteDraft draft);

  Future<void> discardDraft(String routeId);

  /// Moves an owned route from pending_review/published back to draft so it
  /// can be edited again; the route is unlisted from the public catalog.
  Future<RoutePublicationReceipt> withdraw(String routeId);

  /// Road geometry for points the author has placed but not saved yet.
  ///
  /// The static map endpoint needs a route id, so before this the publish
  /// form could only draw a stylised diagram — the author picked real places
  /// and saw no real map and no roads between them.
  Future<RouteDraftPreview> previewRoute({
    required List<String> placeIds,
    String transportMode = 'walk',
  });
}

/// Result of [RoutePublicationRepository.previewRoute].
class RouteDraftPreview {
  const RouteDraftPreview({
    required this.previewId,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.synthetic,
  });

  final String previewId;
  final RouteGeometry? geometry;
  final int distanceMeters;
  final int durationSeconds;

  /// The routing provider was unreachable and this is straight segments
  /// between the points, not roads. Worth drawing, not worth claiming.
  final bool synthetic;

  /// Raster for this preview, fetched by the map widget as a plain image.
  String get staticMapPath => '/api/v1/routes/drafts/preview/$previewId/map';

  factory RouteDraftPreview.fromJson(Map<String, dynamic> json) {
    final geometryJson = json['geometry'] as Map<String, dynamic>?;
    return RouteDraftPreview(
      previewId: json['preview_id'] as String,
      geometry: geometryJson == null
          ? null
          : RouteGeometry.fromJson(geometryJson),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      synthetic: json['synthetic'] as bool? ?? false,
    );
  }
}

class RoutePublicationReceipt {
  const RoutePublicationReceipt({
    required this.id,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final RoutePublicationStatus status;
  final DateTime updatedAt;
}
