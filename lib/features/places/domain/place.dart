class PlaceCategory {
  const PlaceCategory({
    required this.id,
    required this.code,
    required this.slug,
    required this.name,
  });

  final String id;
  final String code;
  final String slug;
  final String name;

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['id'] as String,
      code: json['code'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }
}

class PlaceSummary {
  const PlaceSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.shortDescription,
    required this.lat,
    required this.lng,
    required this.categories,
    this.difficulty,
    this.isPaid = false,
    this.coverImageUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final double lat;
  final double lng;
  final String? difficulty;
  final bool isPaid;
  final String? coverImageUrl;
  final List<PlaceCategory> categories;

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] as List<dynamic>? ?? const [];
    return PlaceSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      shortDescription: json['short_description'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      difficulty: json['difficulty'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      coverImageUrl: json['cover_image_url'] as String?,
      categories: categoriesJson
          .map((item) => PlaceCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlaceDetail extends PlaceSummary {
  const PlaceDetail({
    required super.id,
    required super.name,
    required super.slug,
    required super.shortDescription,
    required super.lat,
    required super.lng,
    required super.categories,
    super.difficulty,
    super.isPaid,
    super.coverImageUrl,
    required this.description,
    required this.address,
    required this.seasonality,
    required this.safetyWarnings,
    this.imageUrls = const [],
    this.staticMapUrl,
  });

  final String? description;
  final String? address;
  final List<String> seasonality;
  final List<String> safetyWarnings;
  final List<String> imageUrls;

  /// Backend proxy URL for a cached Static API image; never contains a vendor key.
  final String? staticMapUrl;

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final summary = PlaceSummary.fromJson(json);
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
      description: json['description'] as String?,
      address: json['address'] as String?,
      seasonality: (json['seasonality'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      safetyWarnings: (json['safety_warnings'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      staticMapUrl: json['static_map_url'] as String?,
    );
  }
}

enum PlaceCatalogSort {
  defaultOrder('default'),
  nameAsc('name_asc'),
  nameDesc('name_desc'),
  dateNewest('date_newest'),
  dateOldest('date_oldest');

  const PlaceCatalogSort(this.apiValue);

  final String apiValue;
}

class PlaceListPage {
  const PlaceListPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<PlaceSummary> items;
  final int total;
  final int limit;
  final int offset;

  factory PlaceListPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return PlaceListPage(
      items: itemsJson
          .map((item) => PlaceSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
