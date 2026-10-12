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

class BeanHatsState {
  const BeanHatsState({
    required this.items,
    required this.travelPoints,
    required this.travelPlusActive,
    this.selected,
    this.purchaseAvailable = false,
  });

  final List<BeanHatOption> items;
  final String? selected;
  final int travelPoints;
  final bool travelPlusActive;

  /// Buying for money is not connected yet.
  final bool purchaseAvailable;

  factory BeanHatsState.fromJson(Map<String, dynamic> json) => BeanHatsState(
    selected: json['selected'] as String?,
    travelPoints: (json['travel_points'] as num?)?.toInt() ?? 0,
    travelPlusActive: json['travel_plus_active'] as bool? ?? false,
    purchaseAvailable: json['purchase_available'] as bool? ?? false,
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
}

/// The demo build: the server's catalogue and rules, kept in memory.
class MockBeanHatsRepository implements BeanHatsRepository {
  MockBeanHatsRepository({this.travelPoints = 950});

  final int travelPoints;
  String? _selected;

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
  ];

  BeanHatsState _state() => BeanHatsState(
    selected: _selected,
    travelPoints: travelPoints,
    travelPlusActive: false,
    items: [
      for (final (slug, title, tier, points) in catalog)
        BeanHatOption(
          slug: slug,
          title: title,
          tier: tier,
          pointsRequired: points,
          available:
              tier == BeanHatTier.free ||
              (tier == BeanHatTier.points && travelPoints >= points),
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
}
