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
    this.isRemote = false,
    this.serverMediaId,
  });

  final String id;

  /// Where the file is: a filesystem path for a freshly picked photo, a
  /// bundled asset key when [isAsset], and the API's public path
  /// (`/media/routes/...`) when [isRemote].
  final String path;
  final RouteMediaKind kind;
  final bool isAsset;

  /// The file already lives on the server — it came back with the draft.
  ///
  /// Without this the editor could not tell a public path from a local one:
  /// it tried to open `/media/routes/...` as a file (broken-image tile) and
  /// re-uploading dropped it, so saving a draft opened from the server wiped
  /// its photos (reported 2026-09-08).
  final bool isRemote;

  /// This device's file was uploaded to the server draft and got this id
  /// there. Unlike [isRemote] the local file is still what the tile shows;
  /// the id only stops the next sync from sending the same photo again.
  final String? serverMediaId;

  /// Already on the server, one way or the other.
  bool get isOnServer => isRemote || serverMediaId != null;

  /// The id the server knows this item by (only meaningful when [isOnServer]).
  String get keepId => isRemote ? id : serverMediaId!;

  /// The same file without the id it had in another server draft, so it is
  /// uploaded again into a new one.
  RouteMediaItem withoutServerId() =>
      RouteMediaItem(id: id, path: path, kind: kind, isAsset: isAsset);

  RouteMediaItem copyWith({String? path, String? serverMediaId}) {
    return RouteMediaItem(
      id: id,
      path: path ?? this.path,
      kind: kind,
      isAsset: isAsset,
      isRemote: isRemote,
      serverMediaId: serverMediaId ?? this.serverMediaId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'kind': kind.name,
    'is_asset': isAsset,
    'is_remote': isRemote,
    'server_media_id': serverMediaId,
  };

  factory RouteMediaItem.fromJson(Map<String, Object?> json) {
    return RouteMediaItem(
      id: json['id']! as String,
      path: json['path']! as String,
      kind: RouteMediaKind.values.byName(json['kind']! as String),
      isAsset: json['is_asset'] as bool? ?? false,
      isRemote: json['is_remote'] as bool? ?? false,
      serverMediaId: json['server_media_id'] as String?,
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
    this.ownerUserId,
    this.clientDraftId,
    this.unsynced = false,
    this.lastSyncedAt,
    this.blockedReason,
    this.blockedFingerprint,
    this.serverUpdatedAt,
  });

  /// The server's `updated_at` from the last save or load: what this copy was
  /// based on. Sent back so a newer change from another device is not
  /// overwritten unseen. Not the same as [updatedAt], which is the last local edit.
  final DateTime? serverUpdatedAt;

  /// Whose draft this is. A draft with another owner (or none) is never shown
  /// or sent: it belongs to somebody who used this device before.
  final String? ownerUserId;

  /// Generated on the device; the server uses it to recognise a retried save.
  final String? clientDraftId;

  /// Edits made since the last successful send to the server.
  final bool unsynced;
  final DateTime? lastSyncedAt;

  /// Why a send keeps failing for good (`places`, `media`) and what the
  /// offending part looked like, so it is not retried until that part changes.
  final String? blockedReason;
  final String? blockedFingerprint;

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

  /// Whether [other] holds the same form content (ignoring the bookkeeping:
  /// owner, keys, sync marks). Decides if an edit happened at all.
  bool sameContentAs(RouteDraft other) {
    if (title != other.title ||
        description != other.description ||
        pace != other.pace ||
        difficulty != other.difficulty ||
        start?.id != other.start?.id ||
        finish?.id != other.finish?.id ||
        media.length != other.media.length ||
        stops.length != other.stops.length ||
        filters.length != other.filters.length) {
      return false;
    }
    for (var i = 0; i < media.length; i++) {
      if (media[i].id != other.media[i].id ||
          media[i].path != other.media[i].path) {
        return false;
      }
    }
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].location.id != other.stops[i].location.id) return false;
    }
    for (var i = 0; i < filters.length; i++) {
      if (filters[i] != other.filters[i]) return false;
    }
    return true;
  }

  /// Already through review: saving it on the server puts it back in the queue.
  bool get isLiveRoute =>
      publicationStatus == RoutePublicationStatus.pendingReview ||
      publicationStatus == RoutePublicationStatus.published;

  /// The parts the server refuses when they are unusable.
  String get placesFingerprint => [
    ?start?.id,
    for (final stop in stops) stop.location.id,
    ?finish?.id,
  ].join(',');

  String get mediaFingerprint => [
    for (final item in media)
      if (!item.isAsset) item.id,
  ].join(',');

  bool get isBlocked {
    final reason = blockedReason;
    if (reason == null) return false;
    return switch (reason) {
      'places' => blockedFingerprint == placesFingerprint,
      'media' => blockedFingerprint == mediaFingerprint,
      _ => false,
    };
  }

  bool get hasMeaningfulContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      media.isNotEmpty ||
      start != null ||
      finish != null ||
      stops.isNotEmpty ||
      filters.isNotEmpty ||
      serverId != null;

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
    String? ownerUserId,
    String? clientDraftId,
    bool? unsynced,
    DateTime? lastSyncedAt,
    String? blockedReason,
    String? blockedFingerprint,
    DateTime? serverUpdatedAt,
    bool clearBlocked = false,
    bool clearServer = false,
  }) {
    return RouteDraft(
      serverUpdatedAt: clearServer
          ? null
          : serverUpdatedAt ?? this.serverUpdatedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      clientDraftId: clientDraftId ?? this.clientDraftId,
      unsynced: unsynced ?? this.unsynced,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      blockedReason: clearBlocked ? null : blockedReason ?? this.blockedReason,
      blockedFingerprint: clearBlocked
          ? null
          : blockedFingerprint ?? this.blockedFingerprint,
      serverId: clearServer ? null : serverId ?? this.serverId,
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
    'owner_user_id': ownerUserId,
    'client_draft_id': clientDraftId,
    'unsynced': unsynced,
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'blocked_reason': blockedReason,
    'blocked_fingerprint': blockedFingerprint,
    'server_updated_at': serverUpdatedAt?.toIso8601String(),
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
      ownerUserId: json['owner_user_id'] as String?,
      clientDraftId: json['client_draft_id'] as String?,
      unsynced: json['unsynced'] as bool? ?? false,
      lastSyncedAt: DateTime.tryParse(json['last_synced_at'] as String? ?? ''),
      blockedReason: json['blocked_reason'] as String?,
      blockedFingerprint: json['blocked_fingerprint'] as String?,
      serverUpdatedAt: DateTime.tryParse(
        json['server_updated_at'] as String? ?? '',
      ),
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
