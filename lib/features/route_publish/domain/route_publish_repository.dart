import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';

abstract interface class RouteDraftRepository {
  Future<RouteDraft?> load();

  Future<void> save(RouteDraft draft);
}

abstract interface class RoutePublicationRepository {
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft);

  Future<RoutePublicationReceipt> submit(RouteDraft draft);
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
