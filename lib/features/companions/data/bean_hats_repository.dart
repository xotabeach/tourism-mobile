import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';

enum BeanHatTier {
  free,
  points,
  premium;

  static BeanHatTier parse(Object? value) => switch (value) {
    'points' => points,
    'premium' => premium,
    _ => free,
  };
}

/// One hat in the catalogue and whether this person may wear it.
class BeanHatOption {
  const BeanHatOption({
    required this.slug,
    required this.title,
    required this.tier,
    required this.available,
    this.pointsRequired = 0,
  });

  final String slug;
  final String title;
  final BeanHatTier tier;
  final int pointsRequired;
  final bool available;

  factory BeanHatOption.fromJson(Map<String, dynamic> json) => BeanHatOption(
    slug: json['slug'] as String,
    title: json['title'] as String? ?? '',
    tier: BeanHatTier.parse(json['tier']),
    pointsRequired: (json['points_required'] as num?)?.toInt() ?? 0,
    available: json['available'] as bool? ?? false,
  );
}

/// Everything «Мой персонаж» shows: hats, the four builds and clothes
/// (FRONTEND-72, FRONTEND-79).
class BeanHatsState {
  const BeanHatsState({
    required this.items,
    required this.travelPoints,
    required this.travelPlusActive,
    this.selected,
    this.purchaseAvailable = false,
    this.isExpert = false,
    this.kind,
    this.kinds = const [],
    this.outfit,
    this.outfits = const [],
  });

  final List<BeanHatOption> items;
  final String? selected;
  final int travelPoints;
  final bool travelPlusActive;

  /// An expert has every hat and every outfit.
  final bool isExpert;

  /// The chosen build; null is the one the account was given.
  final String? kind;

  /// The builds as (slug, title); all free.
  final List<(String, String)> kinds;

  /// The chosen clothes; null is none.
  final String? outfit;
  final List<BeanHatOption> outfits;

  /// Buying for money is not connected yet.
  final bool purchaseAvailable;

  factory BeanHatsState.fromJson(Map<String, dynamic> json) => BeanHatsState(
    selected: json['selected'] as String?,
    travelPoints: (json['travel_points'] as num?)?.toInt() ?? 0,
    travelPlusActive: json['travel_plus_active'] as bool? ?? false,
    purchaseAvailable: json['purchase_available'] as bool? ?? false,
    isExpert: json['is_expert'] as bool? ?? false,
    kind: json['kind'] as String?,
    kinds: [
      for (final item in json['kinds'] as List<dynamic>? ?? const [])
        ((item as Map)['slug'] as String, item['title'] as String? ?? ''),
    ],
    outfit: json['outfit'] as String?,
    outfits: [
      for (final item in json['outfits'] as List<dynamic>? ?? const [])
        BeanHatOption.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    items: [
      for (final item in json['items'] as List<dynamic>? ?? const [])
        BeanHatOption.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );
}

abstract interface class BeanHatsRepository {
  Future<BeanHatsState> load();

  /// Null goes back to the hat the account was given.
  Future<BeanHatsState> select(String? slug);

  /// Null goes back to the build the account was given.
  Future<BeanHatsState> selectKind(String? slug);

  /// Null takes the clothes off.
  Future<BeanHatsState> selectOutfit(String? slug);
}

class ApiBeanHatsRepository implements BeanHatsRepository {
  ApiBeanHatsRepository(this._dio);

  final Dio _dio;

  @override
  Future<BeanHatsState> load() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me/bean-hats',
    );
    return BeanHatsState.fromJson(response.data!);
  });

  @override
  Future<BeanHatsState> select(String? slug) => guardApiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/me/bean-hat',
      data: {'slug': slug},
    );
    return BeanHatsState.fromJson(response.data!);
  });

  @override
  Future<BeanHatsState> selectKind(String? slug) => guardApiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/me/bean-kind',
      data: {'slug': slug},
    );
    return BeanHatsState.fromJson(response.data!);
  });

  @override
  Future<BeanHatsState> selectOutfit(String? slug) => guardApiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/me/bean-outfit',
      data: {'slug': slug},
    );
    return BeanHatsState.fromJson(response.data!);
  });
}

/// The demo build: the server's catalogue and rules, kept in memory.
class MockBeanHatsRepository implements BeanHatsRepository {
  MockBeanHatsRepository({this.travelPoints = 950});

  final int travelPoints;
  String? _selected;
  String? _kind;
  String? _outfit;

  static const kindCatalog = [
    ('pin', 'Синий'),
    ('tall', 'Зелёный'),
    ('small', 'Жёлтый'),
    ('round', 'Красный'),
  ];

  static const outfitCatalog = [
    ('hoodie', 'Худи', BeanHatTier.free, 0),
    ('sweater', 'Свитер в полоску', BeanHatTier.free, 0),
    ('varsity', 'Бомбер', BeanHatTier.points, 1500),
    ('vest', 'Жилет с сумкой', BeanHatTier.premium, 0),
  ];

  static const catalog = [
    ('beanie', 'Шапка с помпоном', BeanHatTier.free, 0),
    ('cap', 'Кепка', BeanHatTier.free, 0),
    ('headband', 'Повязка с листиком', BeanHatTier.free, 0),
    ('tuft', 'Хохолок', BeanHatTier.free, 0),
    ('panama', 'Панама', BeanHatTier.points, 300),
    ('straw_hat', 'Соломенная шляпа', BeanHatTier.points, 800),
    ('bandana', 'Бандана', BeanHatTier.points, 1500),
    ('ushanka', 'Ушанка', BeanHatTier.points, 3000),
    ('beret', 'Берет', BeanHatTier.points, 5000),
    ('climbing_helmet', 'Каска альпиниста', BeanHatTier.points, 8000),
    ('cowboy', 'Ковбойская шляпа', BeanHatTier.premium, 0),
    ('crown', 'Корона', BeanHatTier.premium, 0),
    ('tricorn', 'Треуголка', BeanHatTier.premium, 0),
    ('viking', 'Шлем викинга', BeanHatTier.premium, 0),
    ('chef', 'Колпак повара', BeanHatTier.premium, 0),
    ('top_hat', 'Цилиндр', BeanHatTier.premium, 0),
    ('wreath', 'Венок', BeanHatTier.premium, 0),
    ('sailor', 'Бескозырка', BeanHatTier.premium, 0),
    ('wizard', 'Колпак волшебника', BeanHatTier.premium, 0),
    ('party', 'Праздничный колпак', BeanHatTier.premium, 0),
    ('headphones', 'Наушники', BeanHatTier.points, 500),
  ];

  bool _open(BeanHatTier tier, int points) =>
      tier == BeanHatTier.free ||
      (tier == BeanHatTier.points && travelPoints >= points);

  BeanHatsState _state() => BeanHatsState(
    selected: _selected,
    travelPoints: travelPoints,
    travelPlusActive: false,
    kind: _kind,
    kinds: kindCatalog,
    outfit: _outfit,
    outfits: [
      for (final (slug, title, tier, points) in outfitCatalog)
        BeanHatOption(
          slug: slug,
          title: title,
          tier: tier,
          pointsRequired: points,
          available: _open(tier, points),
        ),
    ],
    items: [
      for (final (slug, title, tier, points) in catalog)
        BeanHatOption(
          slug: slug,
          title: title,
          tier: tier,
          pointsRequired: points,
          available: _open(tier, points),
        ),
    ],
  );

  @override
  Future<BeanHatsState> load() async => _state();

  @override
  Future<BeanHatsState> select(String? slug) async {
    _selected = slug;
    return _state();
  }

  @override
  Future<BeanHatsState> selectKind(String? slug) async {
    _kind = slug;
    return _state();
  }

  @override
  Future<BeanHatsState> selectOutfit(String? slug) async {
    _outfit = slug;
    return _state();
  }
}
