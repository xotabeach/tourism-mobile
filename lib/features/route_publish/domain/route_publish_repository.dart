import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

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
