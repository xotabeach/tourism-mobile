import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/domain/places_repository.dart';

class MockPlacesRepository implements PlacesRepository {
  static const _viewpoint = PlaceCategory(
    id: 'c-viewpoint',
    code: 'viewpoint',
    slug: 'viewpoint',
    name: 'Смотровые',
  );
  static const _nature = PlaceCategory(
    id: 'c-nature',
    code: 'nature',
    slug: 'nature',
    name: 'Природа',
  );
  static const _heritage = PlaceCategory(
    id: 'c-heritage',
    code: 'heritage',
    slug: 'heritage',
    name: 'Наследие',
  );
  static const _beach = PlaceCategory(
    id: 'c-beach',
    code: 'beach',
    slug: 'beach',
    name: 'Море',
  );

  static const _items = [
    PlaceSummary(
      id: 'mock-swallow-nest',
      name: 'Ласточкино гнездо',
      slug: 'swallow-nest',
      coverImageUrl: AppImages.welcomeSunset,
      shortDescription: 'Символ Южного берега Крыма на Аврориной скале.',
      lat: 44.4307,
      lng: 34.1235,
      difficulty: 'easy',
      isPaid: true,
      categories: [_viewpoint, _heritage],
    ),
    PlaceSummary(
      id: 'mock-ai-petri',
      name: 'Ай-Петри',
      slug: 'ai-petri',
      coverImageUrl: AppImages.coastPineTwilight,
      shortDescription: 'Горный пик с панорамой ЮБК.',
      lat: 44.451,
      lng: 34.055,
      difficulty: 'moderate',
      categories: [_nature, _viewpoint],
    ),
    PlaceSummary(
      id: 'mock-vorontsov-palace',
      name: 'Воронцовский дворец',
      slug: 'vorontsov-palace',
      coverImageUrl: AppImages.coastalBayHills,
      shortDescription: 'Дворец и парк в Алупке у подножия Ай-Петри.',
      lat: 44.4197,
      lng: 34.0559,
      difficulty: 'easy',
      isPaid: true,
      categories: [_heritage],
    ),
    PlaceSummary(
      id: 'mock-livadia-palace',
      name: 'Ливадийский дворец',
      slug: 'livadia-palace',
      coverImageUrl: AppImages.welcomeSunset,
      shortDescription: 'Белоснежная резиденция и Царская тропа у Ялты.',
      lat: 44.4678,
      lng: 34.1435,
      difficulty: 'easy',
      isPaid: true,
      categories: [_heritage],
    ),
    PlaceSummary(
      id: 'mock-khan-palace',
      name: 'Ханский дворец',
      slug: 'khan-palace',
      coverImageUrl: AppImages.coastalBayHills,
      shortDescription: 'Резиденция крымских ханов в Бахчисарае.',
      lat: 44.7489,
      lng: 33.8819,
      difficulty: 'easy',
      isPaid: true,
      categories: [_heritage],
    ),
    PlaceSummary(
      id: 'mock-chufut-kale',
      name: 'Чуфут-Кале',
      slug: 'chufut-kale',
      coverImageUrl: AppImages.coastPineTwilight,
      shortDescription: 'Пещерный город над ущельем Марьям-Дере.',
      lat: 44.7408,
      lng: 33.9244,
      difficulty: 'moderate',
      categories: [_heritage, _nature],
    ),
    PlaceSummary(
      id: 'mock-cape-fiolent',
      name: 'Мыс Фиолент',
      slug: 'cape-fiolent',
      coverImageUrl: AppImages.capeFiolentFog,
      shortDescription: 'Скалистый берег, сосны и лестница к Яшмовому пляжу.',
      lat: 44.498,
      lng: 33.489,
      difficulty: 'moderate',
      categories: [_beach, _nature, _viewpoint],
    ),
    PlaceSummary(
      id: 'mock-new-world',
      name: 'Новый Свет',
      slug: 'novy-svet',
      coverImageUrl: AppImages.capeFiolentFog,
      shortDescription: 'Тропа Голицына, гроты и бухты у Судака.',
      lat: 44.827,
      lng: 34.913,
      difficulty: 'easy',
      categories: [_beach, _nature],
    ),
  ];

  static const _details = <String, ({String description, String? address})>{
    'mock-swallow-nest': (
      description:
          'Замок на отвесной скале над морем — визитная карточка Южного берега.',
      address: 'пос. Гаспра, Алупкинское шоссе',
    ),
    'mock-ai-petri': (
      description:
          'Вершина Главной гряды: канатная дорога, зубцы и открытый ветер.',
      address: 'Ялтинский горно-лесной заповедник',
    ),
    'mock-vorontsov-palace': (
      description:
          'Английская неоготика и южный фасад с видом на море; парк с фонтанами.',
      address: 'Алупка, Дворцовое шоссе, 18',
    ),
    'mock-livadia-palace': (
      description:
          'Место Ялтинской конференции; парк и Царская тропа к Ореанде.',
      address: 'пгт Ливадия, ул. Батурина, 44а',
    ),
    'mock-khan-palace': (
      description:
          'Дворцовый комплекс XVI–XVIII вв.: мечети, гаремы и фонтан слёз.',
      address: 'Бахчисарай, ул. Речная, 133',
    ),
    'mock-chufut-kale': (
      description:
          'Средневековая крепость на плато; кенасы и панорама над каньоном.',
      address: 'Бахчисарайский район',
    ),
    'mock-cape-fiolent': (
      description:
          'Вулканические скалы, Георгиевский монастырь и спуск к чистой воде.',
      address: 'Севастополь, мыс Фиолент',
    ),
    'mock-new-world': (
      description: 'Голицынская тропа вдоль скал, гроты и бухта Разбойничья.',
      address: 'пгт Новый Свет, Судак',
    ),
  };

  @override
  Future<PlaceListPage> listPlaces({
    String? regionSlug,
    String? category,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var items = List<PlaceSummary>.from(_items);
    if (category != null && category.isNotEmpty) {
      final needle = category.toLowerCase();
      items = items
          .where(
            (item) => item.categories.any(
              (c) =>
                  c.slug.toLowerCase() == needle ||
                  c.code.toLowerCase() == needle,
            ),
          )
          .toList();
    }
    if (query != null && query.isNotEmpty) {
      final needle = query.trim().toLowerCase();
      items = items.where((item) {
        final haystack =
            '${item.name} ${item.shortDescription ?? ''} '
                    '${item.categories.map((category) => category.name).join(' ')}'
                .toLowerCase();
        return haystack.contains(needle);
      }).toList();
    }
    final total = items.length;
    final page = items.skip(offset).take(limit).toList(growable: false);
    return PlaceListPage(items: page, total: total, limit: limit, offset: offset);
  }

  @override
  Future<PlaceDetail> getPlace(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final summary = _items.firstWhere(
      (item) => item.id == id || item.slug == id,
      orElse: () => _items.first,
    );
    final extra = _details[summary.id];
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
      coverImageUrl: summary.coverImageUrl,
      description: extra?.description ?? summary.shortDescription,
      address: extra?.address,
      seasonality: const ['spring', 'summer', 'autumn'],
      safetyWarnings: summary.difficulty == 'moderate'
          ? const ['Скользкие тропы после дождя', 'Сильный ветер на смотровых']
          : const [],
    );
  }
}
