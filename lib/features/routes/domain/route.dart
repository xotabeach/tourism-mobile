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

enum RouteCatalogSort {
  defaultOrder('default'),
  popular('popular'),
  recent('recent');

  const RouteCatalogSort(this.apiValue);

  final String apiValue;
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
    this.coverImageUrl,
    this.ownerUserId,
    this.authorAvatarUrl,
    this.authorIsExpert = false,
    this.source,
    this.visibility,
    this.lifecycleStatus,
    this.publicationStatus,
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
  final String? coverImageUrl;
  final String? ownerUserId;
  final String? authorAvatarUrl;
  final bool authorIsExpert;
  final String? source;
  final String? visibility;
  final String? lifecycleStatus;
  final String? publicationStatus;

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
      coverImageUrl: json['cover_image_url'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      source: json['source'] as String?,
      visibility: json['visibility'] as String?,
      lifecycleStatus: json['lifecycle_status'] as String?,
      publicationStatus: json['publication_status'] as String?,
    );
  }
}

class RouteDetailMedia {
  const RouteDetailMedia({
    required this.id,
    required this.url,
    required this.kind,
    required this.position,
  });

  final String id;
  final String url;
  final String kind;
  final int position;

  bool get isImage => kind == 'image';

  factory RouteDetailMedia.fromJson(Map<String, dynamic> json) {
    return RouteDetailMedia(
      id: json['id'] as String,
      url: json['url'] as String,
      kind: json['kind'] as String,
      position: json['position'] as int,
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
    super.coverImageUrl,
    super.ownerUserId,
    super.authorAvatarUrl,
    super.authorIsExpert,
    super.source,
    super.visibility,
    super.lifecycleStatus,
    super.publicationStatus,
    required this.description,
    required this.stops,
    this.media = const [],
  });

  final String? description;
  final List<RouteStop> stops;
  final List<RouteDetailMedia> media;

  factory RouteDetail.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['stops'] as List<dynamic>? ?? const [];
    final mediaJson = json['media'] as List<dynamic>? ?? const [];
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
      coverImageUrl: json['cover_image_url'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      source: json['source'] as String?,
      visibility: json['visibility'] as String?,
      lifecycleStatus: json['lifecycle_status'] as String?,
      publicationStatus: json['publication_status'] as String?,
      description: json['description'] as String?,
      stops: stopsJson
          .map((item) => RouteStop.fromJson(item as Map<String, dynamic>))
          .toList(),
      media: mediaJson
          .map(
            (item) => RouteDetailMedia.fromJson(item as Map<String, dynamic>),
          )
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
