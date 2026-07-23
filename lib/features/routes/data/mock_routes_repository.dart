import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';

class MockRoutesRepository implements RoutesRepository {
  static const _routes = <RouteDetail>[
    RouteDetail(
      id: 'route-south-coast',
      name: 'Классика Южного берега',
      slug: 'south-coast-classics',
      shortDescription: 'Дворцы и символ Крыма за один день у Ялты.',
      description:
          'Редакционный маршрут: Воронцовский дворец, Ливадия и Ласточкино гнездо.',
      stopsCount: 3,
      estimatedDurationMinutes: 360,
      distanceMeters: 28000,
      difficulty: 'easy',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'КрымТрип редакция',
      stops: [
        RouteStop(
          id: 'stop-1',
          position: 1,
          placeId: 'p1',
          placeName: 'Воронцовский дворец',
          placeSlug: 'vorontsov-palace',
          visitDurationMinutes: 90,
        ),
        RouteStop(
          id: 'stop-2',
          position: 2,
          placeId: 'p2',
          placeName: 'Ливадийский дворец',
          placeSlug: 'livadia-palace',
          visitDurationMinutes: 75,
        ),
        RouteStop(
          id: 'stop-3',
          position: 3,
          placeId: 'p3',
          placeName: 'Ласточкино гнездо',
          placeSlug: 'swallow-nest',
          visitDurationMinutes: 60,
        ),
      ],
    ),
    RouteDetail(
      id: 'route-bakhchisaray',
      name: 'Наследие Бахчисарая',
      slug: 'bakhchisaray-heritage',
      shortDescription: 'Ханский дворец и пещерный город Чуфут-Кале.',
      description: 'Исторический день в Бахчисарае.',
      stopsCount: 2,
      estimatedDurationMinutes: 300,
      distanceMeters: 12000,
      difficulty: 'moderate',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'КрымТрип редакция',
      stops: [
        RouteStop(
          id: 'stop-4',
          position: 1,
          placeId: 'p4',
          placeName: 'Ханский дворец',
          placeSlug: 'khan-palace',
          visitDurationMinutes: 90,
        ),
        RouteStop(
          id: 'stop-5',
          position: 2,
          placeId: 'p5',
          placeName: 'Чуфут-Кале',
          placeSlug: 'chufut-kale',
          visitDurationMinutes: 120,
        ),
      ],
    ),
  ];

  @override
  Future<RouteListPage> listRoutes({String? regionSlug}) async {
    return RouteListPage(
      items: _routes,
      total: _routes.length,
      limit: 20,
      offset: 0,
    );
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    return _routes.firstWhere(
      (route) => route.id == id,
      orElse: () => throw StateError('Route not found'),
    );
  }
}
