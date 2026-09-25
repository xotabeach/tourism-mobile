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
    this.placeShortDescription,
    this.placeCoverUrl,
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
  final String? placeShortDescription;
  final String? placeCoverUrl;

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
      placeShortDescription: json['place_short_description'] as String?,
      placeCoverUrl: json['place_cover_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'place_id': placeId,
    'place_name': placeName,
    'place_slug': placeSlug,
    'visit_duration_minutes': visitDurationMinutes,
    'note': note,
    'is_optional': isOptional,
    'lat': lat,
    'lng': lng,
    'place_short_description': placeShortDescription,
    'place_cover_url': placeCoverUrl,
  };
}

enum RouteCatalogSort {
  defaultOrder('default'),
  popular('popular'),
  recent('recent'),
  nameAsc('name_asc'),
  nameDesc('name_desc'),
  dateNewest('date_newest'),
  dateOldest('date_oldest');

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
    this.difficultyLevel,
    this.difficultyAuto,
    this.difficultySource = 'auto',
    this.difficultyConfidence,
    this.ratingAverage,
    this.ratingCount = 0,
    this.transportMode,
    this.isRoundTrip = false,
    this.suitableForChildren,
    this.petsAllowed,
    this.isSeaside,
    this.seasonality = const [],
    this.authorLabel,
    this.coverImageUrl,
    this.ownerUserId,
    this.authorAvatarUrl,
    this.authorIsExpert = false,
    this.authorRankTitle,
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

  /// Spec 17: the shown level 1..5 (the author's or editors' rating, or the
  /// estimate), the estimate itself, whose rating is shown and how sure the
  /// estimate is. Older servers send only [difficulty].
  final int? difficultyLevel;
  final int? difficultyAuto;
  final String difficultySource;
  final String? difficultyConfidence;

  /// Level 1..5 to draw: the server's number, else the old word.
  int get shownDifficulty =>
      difficultyLevel ?? legacyDifficultyLevel(difficulty);

  /// Whether the route says anything about its difficulty at all.
  bool get hasDifficulty => difficultyLevel != null || difficulty != null;

  /// Среднее по опубликованным отзывам. `null`, пока нет ни одной оценки —
  /// карточка в этом случае не рисует звезду вовсе: пустая звезда читается
  /// как «плохой маршрут», а это неправда про новый маршрут.
  final double? ratingAverage;
  final int ratingCount;
  final String? transportMode;
  final bool isRoundTrip;

  /// Backend already sends these; the card builds its chips from them.
  final bool? suitableForChildren;
  final bool? petsAllowed;

  /// Editor's «Море» tag (BACKEND-19). `null` from a server that predates it.
  final bool? isSeaside;
  final List<String> seasonality;
  final String? authorLabel;

  /// Owner's travel rank. `null` for editorial routes (no owning user).
  final String? authorRankTitle;
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
      difficultyLevel: (json['difficulty_level'] as num?)?.toInt(),
      difficultyAuto: (json['difficulty_auto'] as num?)?.toInt(),
      difficultySource: json['difficulty_source'] as String? ?? 'auto',
      difficultyConfidence: json['difficulty_confidence'] as String?,
      ratingAverage: (json['rating_average'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      transportMode: json['transport_mode'] as String?,
      isRoundTrip: json['is_round_trip'] as bool? ?? false,
      suitableForChildren: json['suitable_for_children'] as bool?,
      petsAllowed: json['pets_allowed'] as bool?,
      isSeaside: json['is_seaside'] as bool?,
      seasonality: (json['seasonality'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      authorLabel: json['author_label'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      authorRankTitle: json['author_rank_title'] as String?,
      source: json['source'] as String?,
      visibility: json['visibility'] as String?,
      lifecycleStatus: json['lifecycle_status'] as String?,
      publicationStatus: json['publication_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'short_description': shortDescription,
    'stops_count': stopsCount,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'distance_meters': distanceMeters,
    'difficulty': difficulty,
    'difficulty_level': difficultyLevel,
    'difficulty_auto': difficultyAuto,
    'difficulty_source': difficultySource,
    'difficulty_confidence': difficultyConfidence,
    'rating_average': ratingAverage,
    'rating_count': ratingCount,
    'transport_mode': transportMode,
    'is_round_trip': isRoundTrip,
    'suitable_for_children': suitableForChildren,
    'pets_allowed': petsAllowed,
    'is_seaside': isSeaside,
    'seasonality': seasonality,
    'author_label': authorLabel,
    'cover_image_url': coverImageUrl,
    'owner_user_id': ownerUserId,
    'author_avatar_url': authorAvatarUrl,
    'author_is_expert': authorIsExpert,
    'author_rank_title': authorRankTitle,
    'source': source,
    'visibility': visibility,
    'lifecycle_status': lifecycleStatus,
    'publication_status': publicationStatus,
  };
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'kind': kind,
    'position': position,
  };
}

class RouteGeometry {
  const RouteGeometry({required this.coordinates});

  final List<RouteCoordinate> coordinates;

  factory RouteGeometry.fromJson(Map<String, dynamic> json) {
    final raw = json['coordinates'];
    final coordinates = raw is List
        ? raw
              .whereType<List<dynamic>>()
              .where((pair) => pair.length >= 2)
              .map(
                (pair) => RouteCoordinate(
                  lng: (pair[0] as num).toDouble(),
                  lat: (pair[1] as num).toDouble(),
                ),
              )
              .toList(growable: false)
        : const <RouteCoordinate>[];
    return RouteGeometry(coordinates: coordinates);
  }

  Map<String, dynamic> toJson() => {
    'type': 'LineString',
    'coordinates': [
      for (final point in coordinates) [point.lng, point.lat],
    ],
  };
}

/// A continuous run of a route's stops walked or driven in one day (spec 14a).
class RouteDay {
  const RouteDay({
    required this.dayIndex,
    required this.firstStopId,
    required this.lastStopId,
    this.boundarySource = 'auto',
    this.overnightNote,
    this.overloaded = false,
    this.difficultyLevel,
  });

  final int dayIndex;
  final String firstStopId;
  final String lastStopId;

  /// `auto` from the route's norms, `manual` once someone moved it.
  final String boundarySource;

  /// «Ночлег в районе: …»; null on the last day.
  final String? overnightNote;

  /// A leg longer than a whole day leads into it.
  final bool overloaded;

  /// The day's estimated difficulty 1..5 (spec 17); null from older servers.
  final int? difficultyLevel;

  factory RouteDay.fromJson(Map<String, dynamic> json) => RouteDay(
    dayIndex: (json['day_index'] as num).toInt(),
    firstStopId: json['first_stop_id'] as String,
    lastStopId: json['last_stop_id'] as String,
    boundarySource: json['boundary_source'] as String? ?? 'auto',
    overnightNote: json['overnight_note'] as String?,
    overloaded: json['overloaded'] as bool? ?? false,
    difficultyLevel: (json['difficulty_level'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'day_index': dayIndex,
    'first_stop_id': firstStopId,
    'last_stop_id': lastStopId,
    'difficulty_level': difficultyLevel,
    'boundary_source': boundarySource,
    'overnight_note': overnightNote,
    'overloaded': overloaded,
  };
}

/// One stretch of a leg travelled one way (spec 14): a drive, the walk up
/// from the car park (`approach`) or the same walk back (`return`).
class RouteSegment {
  const RouteSegment({
    required this.legIndex,
    required this.seq,
    required this.mode,
    required this.role,
    this.distanceMeters,
    this.durationSeconds,
    this.geometry,
  });

  /// 0 for the leg from the first stop to the second.
  final int legIndex;
  final int seq;

  /// `walk`, `car`, or a transit mode (`bus`, `train`, `cable_car`, ...).
  final String mode;

  /// `main`, `approach` or `return`.
  final String role;
  final int? distanceMeters;
  final int? durationSeconds;
  final RouteGeometry? geometry;

  bool get isWalk => mode == 'walk';

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
    legIndex: (json['leg_index'] as num).toInt(),
    seq: (json['seq'] as num).toInt(),
    mode: json['mode'] as String,
    role: json['role'] as String? ?? 'main',
    distanceMeters: (json['distance_meters'] as num?)?.toInt(),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    geometry: json['geometry'] is Map<String, dynamic>
        ? RouteGeometry.fromJson(json['geometry'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'leg_index': legIndex,
    'seq': seq,
    'mode': mode,
    'role': role,
    'distance_meters': distanceMeters,
    'duration_seconds': durationSeconds,
    'geometry': geometry?.toJson(),
  };
}

class RouteCoordinate {
  const RouteCoordinate({required this.lng, required this.lat});

  final double lng;
  final double lat;
}

class RouteRoutingInfo {
  const RouteRoutingInfo({
    this.provider,
    this.synthetic = false,
    this.qualityStatus = 'unknown',
    this.qualityPolicyVersion,
    this.warnings = const [],
    this.movementDurationSeconds,
    this.visitDurationMinutes,
    this.transferDurationSeconds,
    this.bufferDurationSeconds,
    this.totalDurationSeconds,
    this.elevationGainMeters,
    this.elevationLossMeters,
    this.minAltitudeMeters,
    this.maxAltitudeMeters,
    this.maxRoadAngleDegrees,
    this.roadTypes = const [],
  });

  final String? provider;
  final bool synthetic;
  final String qualityStatus;
  final String? qualityPolicyVersion;
  final List<String> warnings;
  final int? movementDurationSeconds;
  final int? visitDurationMinutes;
  final int? transferDurationSeconds;
  final int? bufferDurationSeconds;
  final int? totalDurationSeconds;
  final int? elevationGainMeters;
  final int? elevationLossMeters;
  final int? minAltitudeMeters;
  final int? maxAltitudeMeters;
  final double? maxRoadAngleDegrees;
  final List<String> roadTypes;

  factory RouteRoutingInfo.fromJson(Map<String, dynamic> json) {
    return RouteRoutingInfo(
      provider: json['provider'] as String?,
      synthetic: json['synthetic'] as bool? ?? false,
      qualityStatus: json['quality_status'] as String? ?? 'unknown',
      qualityPolicyVersion: json['quality_policy_version'] as String?,
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      movementDurationSeconds: json['movement_duration_seconds'] as int?,
      visitDurationMinutes: json['visit_duration_minutes'] as int?,
      transferDurationSeconds: json['transfer_duration_seconds'] as int?,
      bufferDurationSeconds: json['buffer_duration_seconds'] as int?,
      totalDurationSeconds: json['total_duration_seconds'] as int?,
      elevationGainMeters: json['elevation_gain_meters'] as int?,
      elevationLossMeters: json['elevation_loss_meters'] as int?,
      minAltitudeMeters: json['min_altitude_meters'] as int?,
      maxAltitudeMeters: json['max_altitude_meters'] as int?,
      maxRoadAngleDegrees: (json['max_road_angle_degrees'] as num?)?.toDouble(),
      roadTypes: (json['road_types'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'synthetic': synthetic,
    'quality_status': qualityStatus,
    'quality_policy_version': qualityPolicyVersion,
    'warnings': warnings,
    'movement_duration_seconds': movementDurationSeconds,
    'visit_duration_minutes': visitDurationMinutes,
    'transfer_duration_seconds': transferDurationSeconds,
    'buffer_duration_seconds': bufferDurationSeconds,
    'total_duration_seconds': totalDurationSeconds,
    'elevation_gain_meters': elevationGainMeters,
    'elevation_loss_meters': elevationLossMeters,
    'min_altitude_meters': minAltitudeMeters,
    'max_altitude_meters': maxAltitudeMeters,
    'max_road_angle_degrees': maxRoadAngleDegrees,
    'road_types': roadTypes,
  };
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
    super.difficultyLevel,
    super.difficultyAuto,
    super.difficultySource,
    super.difficultyConfidence,
    super.ratingAverage,
    super.ratingCount,
    super.transportMode,
    super.isRoundTrip,
    super.suitableForChildren,
    super.petsAllowed,
    super.isSeaside,
    super.seasonality,
    super.authorLabel,
    super.coverImageUrl,
    super.ownerUserId,
    super.authorAvatarUrl,
    super.authorIsExpert,
    super.authorRankTitle,
    super.source,
    super.visibility,
    super.lifecycleStatus,
    super.publicationStatus,
    required this.description,
    required this.stops,
    this.media = const [],
    this.freshnessStatus,
    this.geometry,
    this.routing,
    this.staticMapUrl,
    this.segments = const [],
    this.days = const [],
    this.difficultyBreakdown,
  });

  /// Why the estimate came out as it did (spec 17); null from older servers.
  final RouteDifficultyBreakdown? difficultyBreakdown;

  final String? description;
  final List<RouteStop> stops;
  final List<RouteDetailMedia> media;
  final String? freshnessStatus;
  final RouteGeometry? geometry;
  final RouteRoutingInfo? routing;

  /// Backend proxy URL for a cached Static API image; never contains a vendor key.
  final String? staticMapUrl;

  /// Every leg's segments in order; empty for routes that have none yet.
  final List<RouteSegment> segments;

  /// Days in order; one for a short route, empty from older servers.
  final List<RouteDay> days;

  /// Segments of the leg that leads to the stop at [stopIndex] (0-based).
  List<RouteSegment> segmentsTo(int stopIndex) => [
    for (final segment in segments)
      if (segment.legIndex == stopIndex - 1) segment,
  ];

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
      difficultyLevel: (json['difficulty_level'] as num?)?.toInt(),
      difficultyAuto: (json['difficulty_auto'] as num?)?.toInt(),
      difficultySource: json['difficulty_source'] as String? ?? 'auto',
      difficultyConfidence: json['difficulty_confidence'] as String?,
      ratingAverage: (json['rating_average'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      transportMode: json['transport_mode'] as String?,
      isRoundTrip: json['is_round_trip'] as bool? ?? false,
      suitableForChildren: json['suitable_for_children'] as bool?,
      petsAllowed: json['pets_allowed'] as bool?,
      isSeaside: json['is_seaside'] as bool?,
      seasonality: (json['seasonality'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      authorLabel: json['author_label'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      authorRankTitle: json['author_rank_title'] as String?,
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
      freshnessStatus: json['freshness_status'] as String?,
      geometry: json['geometry'] is Map<String, dynamic>
          ? RouteGeometry.fromJson(json['geometry'] as Map<String, dynamic>)
          : null,
      routing: json['routing'] is Map<String, dynamic>
          ? RouteRoutingInfo.fromJson(json['routing'] as Map<String, dynamic>)
          : null,
      staticMapUrl: json['static_map_url'] as String?,
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RouteSegment.fromJson)
          .toList(growable: false),
      days: (json['days'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RouteDay.fromJson)
          .toList(growable: false),
      difficultyBreakdown: RouteDifficultyBreakdown.tryParse(
        (json['accessibility'] as Map<String, dynamic>?)?['difficulty'] ??
            json['difficulty_breakdown'],
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'segments': [for (final segment in segments) segment.toJson()],
    'days': [for (final day in days) day.toJson()],
    'difficulty_breakdown': difficultyBreakdown?.toJson(),
    'description': description,
    'freshness_status': freshnessStatus,
    'geometry': geometry?.toJson(),
    'routing': routing?.toJson(),
    'static_map_url': staticMapUrl,
    'stops': [for (final stop in stops) stop.toJson()],
    'media': [for (final item in media) item.toJson()],
  };
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

/// The old difficulty word as a level, as the server maps it (spec 17).
int legacyDifficultyLevel(String? word) => switch (word) {
  'easy' => 2,
  'moderate' => 3,
  'hard' => 4,
  'extreme' || 'expert' => 5,
  _ => 2,
};

/// One reason behind a difficulty estimate: a code and its numbers.
class DifficultyReason {
  const DifficultyReason(this.code, this.values);

  final String code;
  final Map<String, dynamic> values;

  num? _number(String key) => values[key] as num?;

  String _km(num? value) =>
      (value ?? 0).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '');

  /// Words for the breakdown sheet; null for a code this app does not know.
  String? get text => switch (code) {
    'walk_effort' =>
      'Пешком ${_km(_number('km'))} км, набор ${_number('ascent_m') ?? 0} м '
          '(нагрузка как ${_km(_number('effort_km'))} км по ровному)',
    'trail' => switch (values['grade']) {
      'dirt' => 'Грунтовые тропы: ${_km((_number('meters') ?? 0) / 1000)} км',
      final grade =>
        'Горная тропа $grade: ${_km((_number('meters') ?? 0) / 1000)} км',
    },
    'steep' => 'Крутые участки до ${_number('degrees')}°',
    'drive_hours' => 'За рулём ${_km(_number('hours'))} ч',
    'unpaved' => 'Грунтовая дорога ${_km((_number('meters') ?? 0) / 1000)} км',
    'offroad' =>
      'Нужен внедорожник: ${_km((_number('meters') ?? 0) / 1000)} км',
    'serpentine' => 'Серпантин ${_km((_number('meters') ?? 0) / 1000)} км',
    'walk_and_drive' => 'Непросто и идти, и ехать',
    'long_day' => 'Долгий день: ${_hours(_number('minutes'))} с остановками',
    'multi_day' => '${_number('days')} дня подряд, накапливается усталость',
    'low_data' => 'Оценка примерная: мало данных о рельефе',
    _ => null,
  };

  static String _hours(num? minutes) {
    final total = (minutes ?? 0).round();
    final hours = total ~/ 60;
    final rest = total % 60;
    return rest == 0 ? '$hours ч' : '$hours ч $rest мин';
  }

  Map<String, dynamic> toJson() => {'code': code, ...values};
}

/// Why a route's estimate is what it is (spec 17, section 8).
class RouteDifficultyBreakdown {
  const RouteDifficultyBreakdown({
    required this.level,
    required this.confidence,
    required this.reasons,
    this.walkLevel,
    this.driveLevel,
  });

  final int level;
  final int? walkLevel;
  final int? driveLevel;
  final String confidence;
  final List<DifficultyReason> reasons;

  bool get approximate => confidence == 'low';

  static RouteDifficultyBreakdown? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final level = (raw['level'] as num?)?.toInt();
    if (level == null) return null;
    return RouteDifficultyBreakdown(
      level: level,
      walkLevel: (raw['walk_level'] as num?)?.toInt(),
      driveLevel: (raw['drive_level'] as num?)?.toInt(),
      confidence: raw['confidence'] as String? ?? 'low',
      reasons: [
        for (final item in raw['reasons'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic> && item['code'] is String)
            DifficultyReason(item['code'] as String, {
              for (final entry in item.entries)
                if (entry.key != 'code') entry.key: entry.value,
            }),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'walk_level': walkLevel,
    'drive_level': driveLevel,
    'confidence': confidence,
    'reasons': [for (final reason in reasons) reason.toJson()],
  };
}
