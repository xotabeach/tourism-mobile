import 'package:tourism_mobile/core/theme/app_images.dart';
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
          'Редакционный маршрут: Воронцовский дворец, Ливадия и Ласточкино гнездо. '
          'Удобно на авто с остановками на смотровых.',
      stopsCount: 3,
      estimatedDurationMinutes: 360,
      distanceMeters: 28000,
      difficulty: 'easy',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'КрымТрип редакция',
      coverImageUrl: AppImages.welcomeSunset,
      stops: [
        RouteStop(
          id: 'stop-1',
          position: 1,
          placeId: 'mock-vorontsov-palace',
          placeName: 'Воронцовский дворец',
          placeSlug: 'vorontsov-palace',
          visitDurationMinutes: 90,
          lat: 44.4197,
          lng: 34.0559,
        ),
        RouteStop(
          id: 'stop-2',
          position: 2,
          placeId: 'mock-livadia-palace',
          placeName: 'Ливадийский дворец',
          placeSlug: 'livadia-palace',
          visitDurationMinutes: 75,
          lat: 44.4678,
          lng: 34.1435,
        ),
        RouteStop(
          id: 'stop-3',
          position: 3,
          placeId: 'mock-swallow-nest',
          placeName: 'Ласточкино гнездо',
          placeSlug: 'swallow-nest',
          visitDurationMinutes: 60,
          lat: 44.4307,
          lng: 34.1235,
        ),
      ],
    ),
    RouteDetail(
      id: 'route-bakhchisaray',
      name: 'Наследие Бахчисарая',
      slug: 'bakhchisaray-heritage',
      shortDescription: 'Ханский дворец и пещерный город Чуфут-Кале.',
      description:
          'Исторический день в Бахчисарае: дворец ханов и подъём к Чуфут-Кале.',
      stopsCount: 2,
      estimatedDurationMinutes: 300,
      distanceMeters: 12000,
      difficulty: 'moderate',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'КрымТрип редакция',
      coverImageUrl: AppImages.coastPineTwilight,
      stops: [
        RouteStop(
          id: 'stop-4',
          position: 1,
          placeId: 'mock-khan-palace',
          placeName: 'Ханский дворец',
          placeSlug: 'khan-palace',
          visitDurationMinutes: 90,
          lat: 44.7489,
          lng: 33.8819,
        ),
        RouteStop(
          id: 'stop-5',
          position: 2,
          placeId: 'mock-chufut-kale',
          placeName: 'Чуфут-Кале',
          placeSlug: 'chufut-kale',
          visitDurationMinutes: 120,
          lat: 44.7408,
          lng: 33.9244,
        ),
      ],
    ),
    RouteDetail(
      id: 'route-coast-trail',
      name: 'Море и сосны: Фиолент — Новый Свет',
      slug: 'coast-pine-trail',
      shortDescription: 'Скалистый берег, лесные тропы и бухты у моря.',
      description:
          'День у воды: мыс Фиолент с видом на Яшмовый пляж и Голицынская '
          'тропа в Новом Свете. Подходит для пеших отрезков и коротких переездов.',
      stopsCount: 2,
      estimatedDurationMinutes: 420,
      distanceMeters: 95000,
      difficulty: 'moderate',
      transportMode: 'car',
      isRoundTrip: false,
      authorLabel: 'КрымТрип редакция',
      coverImageUrl: AppImages.capeFiolentFog,
      stops: [
        RouteStop(
          id: 'stop-6',
          position: 1,
          placeId: 'mock-cape-fiolent',
          placeName: 'Мыс Фиолент',
          placeSlug: 'cape-fiolent',
          visitDurationMinutes: 120,
          note: 'Спуск к пляжу по лестнице — удобная обувь.',
          lat: 44.498,
          lng: 33.489,
        ),
        RouteStop(
          id: 'stop-7',
          position: 2,
          placeId: 'mock-new-world',
          placeName: 'Новый Свет',
          placeSlug: 'novy-svet',
          visitDurationMinutes: 150,
          lat: 44.827,
          lng: 34.913,
        ),
      ],
    ),
  ];

  @override
  Future<RouteListPage> listRoutes({String? regionSlug}) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return RouteListPage(
      items: _routes,
      total: _routes.length,
      limit: 20,
      offset: 0,
    );
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return _routes.firstWhere(
      (route) => route.id == id || route.slug == id,
      orElse: () => throw StateError('Route not found: $id'),
    );
  }
}
