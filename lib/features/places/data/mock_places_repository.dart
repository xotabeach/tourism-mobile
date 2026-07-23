import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/domain/places_repository.dart';

class MockPlacesRepository implements PlacesRepository {
  static const _items = [
    PlaceSummary(
      id: 'mock-swallow-nest',
      name: 'Ласточкино гнездо',
      slug: 'swallow-nest',
      shortDescription: 'Символ Южного берега Крыма на Аврориной скале.',
      lat: 44.4307,
      lng: 34.1235,
      difficulty: 'easy',
      isPaid: true,
      categories: [
        PlaceCategory(
          id: 'c1',
          code: 'viewpoint',
          slug: 'viewpoint',
          name: 'Смотровые',
        ),
      ],
    ),
    PlaceSummary(
      id: 'mock-ai-petri',
      name: 'Ай-Петри',
      slug: 'ai-petri',
      shortDescription: 'Горный пик с панорамой ЮБК.',
      lat: 44.451,
      lng: 34.055,
      difficulty: 'moderate',
      categories: [
        PlaceCategory(
          id: 'c2',
          code: 'nature',
          slug: 'nature',
          name: 'Природа',
        ),
      ],
    ),
  ];

  @override
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var items = List<PlaceSummary>.from(_items);
    if (query != null && query.isNotEmpty) {
      final needle = query.toLowerCase();
      items = items
          .where((item) => item.name.toLowerCase().contains(needle))
          .toList();
    }
    return PlaceListPage(
      items: items,
      total: items.length,
      limit: 20,
      offset: 0,
    );
  }

  @override
  Future<PlaceDetail> getPlace(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final summary = _items.firstWhere(
      (item) => item.id == id,
      orElse: () => _items.first,
    );
    return PlaceDetail(
      id: summary.id,
      name: summary.name,
      slug: summary.slug,
      shortDescription: summary.shortDescription,
      lat: summary.lat,
      lng: summary.lng,
      categories: summary.categories,
      difficulty: summary.difficulty,
      isPaid: summary.isPaid,
      description: summary.shortDescription,
      address: null,
      seasonality: const ['spring', 'summer', 'autumn'],
      safetyWarnings: const [],
    );
  }
}
