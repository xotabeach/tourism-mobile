class RouteStop {
  const RouteStop({
    required this.id,
    required this.position,
    required this.placeId,
    required this.placeName,
    required this.placeSlug,
    this.visitDurationMinutes,
    this.note,
    this.isOptional = false,
    this.lat,
    this.lng,
  });

  final String id;
  final int position;
  final String placeId;
  final String placeName;
  final String placeSlug;
  final int? visitDurationMinutes;
  final String? note;
  final bool isOptional;
  final double? lat;
  final double? lng;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id'] as String,
      position: json['position'] as int,
      placeId: json['place_id'] as String,
      placeName: json['place_name'] as String,
      placeSlug: json['place_slug'] as String,
      visitDurationMinutes: json['visit_duration_minutes'] as int?,
      note: json['note'] as String?,
      isOptional: json['is_optional'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.shortDescription,
    required this.stopsCount,
    this.estimatedDurationMinutes,
    this.distanceMeters,
    this.difficulty,
    this.transportMode,
    this.isRoundTrip = false,
    this.authorLabel,
  });

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final int stopsCount;
  final int? estimatedDurationMinutes;
  final int? distanceMeters;
  final String? difficulty;
  final String? transportMode;
  final bool isRoundTrip;
  final String? authorLabel;

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      shortDescription: json['short_description'] as String?,
      stopsCount: json['stops_count'] as int,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      distanceMeters: json['distance_meters'] as int?,
      difficulty: json['difficulty'] as String?,
      transportMode: json['transport_mode'] as String?,
      isRoundTrip: json['is_round_trip'] as bool? ?? false,
      authorLabel: json['author_label'] as String?,
    );
  }
}

class RouteDetail extends RouteSummary {
  const RouteDetail({
    required super.id,
    required super.name,
    required super.slug,
    required super.shortDescription,
    required super.stopsCount,
    super.estimatedDurationMinutes,
    super.distanceMeters,
    super.difficulty,
    super.transportMode,
    super.isRoundTrip,
    super.authorLabel,
    required this.description,
    required this.stops,
  });

  final String? description;
  final List<RouteStop> stops;

  factory RouteDetail.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['stops'] as List<dynamic>? ?? const [];
    return RouteDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      shortDescription: json['short_description'] as String?,
      stopsCount: json['stops_count'] as int,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      distanceMeters: json['distance_meters'] as int?,
      difficulty: json['difficulty'] as String?,
      transportMode: json['transport_mode'] as String?,
      isRoundTrip: json['is_round_trip'] as bool? ?? false,
      authorLabel: json['author_label'] as String?,
      description: json['description'] as String?,
      stops: stopsJson
          .map((item) => RouteStop.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouteListPage {
  const RouteListPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<RouteSummary> items;
  final int total;
  final int limit;
  final int offset;

  factory RouteListPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return RouteListPage(
      items: itemsJson
          .map((item) => RouteSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
