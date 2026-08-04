enum RouteMediaKind { image, video }

enum TravelPace { calm, moderate, active }

enum RoutePublicationStatus {
  draft('draft'),
  pendingReview('pending_review'),
  published('published'),
  rejected('rejected'),
  deleted('deleted');

  const RoutePublicationStatus(this.apiValue);
  final String apiValue;

  static RoutePublicationStatus fromApi(String? value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => draft,
    );
  }
}

class RouteMediaItem {
  const RouteMediaItem({
    required this.id,
    required this.path,
    required this.kind,
    this.isAsset = false,
  });

  final String id;
  final String path;
  final RouteMediaKind kind;
  final bool isAsset;

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'kind': kind.name,
    'is_asset': isAsset,
  };

  factory RouteMediaItem.fromJson(Map<String, Object?> json) {
    return RouteMediaItem(
      id: json['id']! as String,
      path: json['path']! as String,
      kind: RouteMediaKind.values.byName(json['kind']! as String),
      isAsset: json['is_asset'] as bool? ?? false,
    );
  }
}

class RouteLocation {
  const RouteLocation({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String subtitle;
  final double lat;
  final double lng;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'lat': lat,
    'lng': lng,
  };

  factory RouteLocation.fromJson(Map<String, Object?> json) {
    return RouteLocation(
      id: json['id']! as String,
      name: json['name']! as String,
      subtitle: json['subtitle']! as String,
      lat: (json['lat']! as num).toDouble(),
      lng: (json['lng']! as num).toDouble(),
    );
  }
}

class RouteStopDraft {
  const RouteStopDraft({required this.location, this.distanceMeters});

  final RouteLocation location;
  final int? distanceMeters;

  RouteStopDraft copyWith({RouteLocation? location, int? distanceMeters}) {
    return RouteStopDraft(
      location: location ?? this.location,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  Map<String, Object?> toJson() => {
    'location': location.toJson(),
    'distance_meters': distanceMeters,
  };

  factory RouteStopDraft.fromJson(Map<String, Object?> json) {
    return RouteStopDraft(
      location: RouteLocation.fromJson(
        Map<String, Object?>.from(json['location']! as Map),
      ),
      distanceMeters: json['distance_meters'] as int?,
    );
  }
}

class RouteDraft {
  const RouteDraft({
    this.serverId,
    this.publicationStatus = RoutePublicationStatus.draft,
    this.title = '',
    this.description = '',
    this.media = const [],
    this.start,
    this.finish,
    this.stops = const [],
    this.filters = const [],
    this.pace = TravelPace.calm,
    this.difficulty = 3,
    this.updatedAt,
  });

  final String? serverId;
  final RoutePublicationStatus publicationStatus;
  final String title;
  final String description;
  final List<RouteMediaItem> media;
  final RouteLocation? start;
  final RouteLocation? finish;
  final List<RouteStopDraft> stops;
  final List<String> filters;
  final TravelPace pace;
  final int difficulty;
  final DateTime? updatedAt;

  static const _goldenLocation = RouteLocation(
    id: 'golden-lenin-square',
    name: 'Площадь Ленина',
    subtitle: 'г. Симферополь',
    lat: 44.9521,
    lng: 34.1024,
  );

  factory RouteDraft.golden() {
    const photo = 'assets/images/publish_photo_1.jpg';
    return const RouteDraft(
      media: [
        RouteMediaItem(
          id: 'golden-photo-1',
          path: photo,
          kind: RouteMediaKind.image,
          isAsset: true,
        ),
        RouteMediaItem(
          id: 'golden-photo-2',
          path: photo,
          kind: RouteMediaKind.image,
          isAsset: true,
        ),
        RouteMediaItem(
          id: 'golden-photo-3',
          path: photo,
          kind: RouteMediaKind.image,
          isAsset: true,
        ),
      ],
      start: _goldenLocation,
      finish: _goldenLocation,
      stops: [
        RouteStopDraft(
          location: RouteLocation(
            id: 'golden-stop-1',
            name: 'Подножье горы',
            subtitle: 'Крым',
            lat: 44.77,
            lng: 33.91,
          ),
          distanceMeters: 1700,
        ),
        RouteStopDraft(
          location: RouteLocation(
            id: 'golden-stop-2',
            name: 'Кафе “Ветер”',
            subtitle: 'Крым',
            lat: 44.75,
            lng: 33.92,
          ),
          distanceMeters: 3500,
        ),
        RouteStopDraft(
          location: RouteLocation(
            id: 'golden-stop-3',
            name: 'Смотровая площадка',
            subtitle: 'Крым',
            lat: 44.73,
            lng: 33.93,
          ),
          distanceMeters: 5400,
        ),
        RouteStopDraft(
          location: RouteLocation(
            id: 'golden-stop-4',
            name: 'Вершина Чок-Сары-Кая',
            subtitle: 'Крым',
            lat: 44.71,
            lng: 33.94,
          ),
          distanceMeters: 8200,
        ),
      ],
      filters: [
        'Природа',
        'Пешком',
        'С детьми',
        'Водопады',
        'Романтика',
        'Смотровые площадки',
        'Леса',
      ],
    );
  }

  RouteDraft copyWith({
    String? serverId,
    RoutePublicationStatus? publicationStatus,
    String? title,
    String? description,
    List<RouteMediaItem>? media,
    RouteLocation? start,
    bool clearStart = false,
    RouteLocation? finish,
    bool clearFinish = false,
    List<RouteStopDraft>? stops,
    List<String>? filters,
    TravelPace? pace,
    int? difficulty,
    DateTime? updatedAt,
  }) {
    return RouteDraft(
      serverId: serverId ?? this.serverId,
      publicationStatus: publicationStatus ?? this.publicationStatus,
      title: title ?? this.title,
      description: description ?? this.description,
      media: media ?? this.media,
      start: clearStart ? null : start ?? this.start,
      finish: clearFinish ? null : finish ?? this.finish,
      stops: stops ?? this.stops,
      filters: filters ?? this.filters,
      pace: pace ?? this.pace,
      difficulty: difficulty ?? this.difficulty,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'server_id': serverId,
    'publication_status': publicationStatus.apiValue,
    'title': title,
    'description': description,
    'media': media.map((item) => item.toJson()).toList(),
    'start': start?.toJson(),
    'finish': finish?.toJson(),
    'stops': stops.map((item) => item.toJson()).toList(),
    'filters': filters,
    'pace': pace.name,
    'difficulty': difficulty,
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory RouteDraft.fromJson(Map<String, Object?> json) {
    final start = json['start'];
    final finish = json['finish'];
    return RouteDraft(
      serverId: json['server_id'] as String?,
      publicationStatus: RoutePublicationStatus.fromApi(
        json['publication_status'] as String?,
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      media: (json['media'] as List? ?? const [])
          .map(
            (item) =>
                RouteMediaItem.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false),
      start: start == null
          ? null
          : RouteLocation.fromJson(Map<String, Object?>.from(start as Map)),
      finish: finish == null
          ? null
          : RouteLocation.fromJson(Map<String, Object?>.from(finish as Map)),
      stops: (json['stops'] as List? ?? const [])
          .map(
            (item) =>
                RouteStopDraft.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false),
      filters: (json['filters'] as List? ?? const []).cast<String>(),
      pace: TravelPace.values.byName(
        json['pace'] as String? ?? TravelPace.calm.name,
      ),
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
