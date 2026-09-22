enum RouteExecutionStatus { active, paused, completed, cancelled }

RouteExecutionStatus routeExecutionStatusFromJson(Object? value) {
  return switch (value) {
    'paused' => RouteExecutionStatus.paused,
    'completed' => RouteExecutionStatus.completed,
    'cancelled' => RouteExecutionStatus.cancelled,
    _ => RouteExecutionStatus.active,
  };
}

class RouteExecutionStop {
  const RouteExecutionStop({
    required this.id,
    required this.position,
    required this.placeName,
    required this.isOptional,
    this.routeStopId,
    this.placeId,
    this.lat,
    this.lng,
    this.completedAt,
    this.legDistanceMeters,
    this.legEstimateSeconds,
    this.legEstimateSource,
    this.paceWarnBelowSeconds,
    this.undelivered = false,
  });

  final String id;
  final int position;
  final String placeName;
  final bool isOptional;
  final String? routeStopId;
  final String? placeId;
  final double? lat;
  final double? lng;
  final DateTime? completedAt;

  /// Length of the leg that ends at this stop (from the previous one).
  final int? legDistanceMeters;

  /// The server's expected time for that leg; null when it has no estimate.
  final int? legEstimateSeconds;
  final String? legEstimateSource;

  /// Warn before a mark that arrives sooner than this after the previous one.
  /// Only present while the server enforces; a hint, the server stays the judge.
  final int? paceWarnBelowSeconds;

  /// A queued mark for this stop was dropped without reaching the server.
  /// Local only: set by the offline coordinator, cleared by a new mark.
  final bool undelivered;

  bool get isCompleted => completedAt != null;

  RouteExecutionStop copyWith({
    DateTime? completedAt,
    int? legDistanceMeters,
    int? legEstimateSeconds,
    String? legEstimateSource,
    int? paceWarnBelowSeconds,
    bool clearPaceWarn = false,
    bool? undelivered,
  }) => RouteExecutionStop(
    id: id,
    position: position,
    placeName: placeName,
    isOptional: isOptional,
    routeStopId: routeStopId,
    placeId: placeId,
    lat: lat,
    lng: lng,
    completedAt: completedAt ?? this.completedAt,
    legDistanceMeters: legDistanceMeters ?? this.legDistanceMeters,
    legEstimateSeconds: legEstimateSeconds ?? this.legEstimateSeconds,
    legEstimateSource: legEstimateSource ?? this.legEstimateSource,
    paceWarnBelowSeconds: clearPaceWarn
        ? null
        : paceWarnBelowSeconds ?? this.paceWarnBelowSeconds,
    undelivered: undelivered ?? this.undelivered,
  );

  /// The same stop, unmarked again (FRONTEND-36).
  RouteExecutionStop withoutCompletion() => RouteExecutionStop(
    id: id,
    position: position,
    placeName: placeName,
    isOptional: isOptional,
    routeStopId: routeStopId,
    placeId: placeId,
    lat: lat,
    lng: lng,
    legDistanceMeters: legDistanceMeters,
    legEstimateSeconds: legEstimateSeconds,
    legEstimateSource: legEstimateSource,
    paceWarnBelowSeconds: paceWarnBelowSeconds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'route_stop_id': routeStopId,
    'place_id': placeId,
    'position': position,
    'place_name': placeName,
    'lat': lat,
    'lng': lng,
    'is_optional': isOptional,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'leg_distance_meters': legDistanceMeters,
    'leg_estimate_seconds': legEstimateSeconds,
    'leg_estimate_source': legEstimateSource,
    'pace_warn_below_seconds': paceWarnBelowSeconds,
    'undelivered': undelivered,
  };

  factory RouteExecutionStop.fromJson(Map<String, dynamic> json) {
    return RouteExecutionStop(
      id: json['id'] as String,
      routeStopId: json['route_stop_id'] as String?,
      placeId: json['place_id'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 1,
      placeName: json['place_name'] as String? ?? 'Остановка',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isOptional: json['is_optional'] as bool? ?? false,
      completedAt: _date(json['completed_at']),
      legDistanceMeters: (json['leg_distance_meters'] as num?)?.toInt(),
      legEstimateSeconds: (json['leg_estimate_seconds'] as num?)?.toInt(),
      legEstimateSource: json['leg_estimate_source'] as String?,
      paceWarnBelowSeconds: (json['pace_warn_below_seconds'] as num?)?.toInt(),
      undelivered: json['undelivered'] as bool? ?? false,
    );
  }
}

/// A position sent with a stop mark so the server can compare it with the
/// stop. Judged once and never stored server-side; kept on the device only
/// inside the encrypted outbox until delivered or dropped.
class MarkPosition {
  const MarkPosition({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyMeters,
  };

  static MarkPosition? tryParse(Object? value) {
    if (value is! Map) return null;
    final lat = (value['lat'] as num?)?.toDouble();
    final lng = (value['lng'] as num?)?.toDouble();
    final accuracy = (value['accuracy_m'] as num?)?.toDouble();
    if (lat == null || lng == null || accuracy == null) return null;
    return MarkPosition(lat: lat, lng: lng, accuracyMeters: accuracy);
  }
}

/// Server-provided switch for client hints; present only while enforcing.
class RouteExecutionAntiFraud {
  const RouteExecutionAntiFraud({
    required this.gpsToleranceMeters,
    required this.gpsMinAccuracyMeters,
    this.routeCooldownDays,
    this.dailyPointsCap,
  });

  final int gpsToleranceMeters;
  final int gpsMinAccuracyMeters;

  /// Limits the server applies to points, for explaining a withheld award.
  /// Null when the server did not say (an older backend).
  final int? routeCooldownDays;
  final int? dailyPointsCap;

  Map<String, dynamic> toJson() => {
    'mode': 'enforce',
    'gps_tolerance_m': gpsToleranceMeters,
    'gps_min_accuracy_m': gpsMinAccuracyMeters,
    'route_cooldown_days': routeCooldownDays,
    'daily_points_cap': dailyPointsCap,
  };

  factory RouteExecutionAntiFraud.fromJson(Map<String, dynamic> json) {
    return RouteExecutionAntiFraud(
      gpsToleranceMeters: (json['gps_tolerance_m'] as num?)?.toInt() ?? 150,
      gpsMinAccuracyMeters:
          (json['gps_min_accuracy_m'] as num?)?.toInt() ?? 100,
      routeCooldownDays: _positiveInt(json['route_cooldown_days']),
      dailyPointsCap: _positiveInt(json['daily_points_cap']),
    );
  }
}

/// How the points of a finished run were settled. `awarded` is the ordinary
/// case and needs no extra UI; the rest explain why a run earned less.
enum RoutePointsStatus { none, awarded, held, rejected }

RoutePointsStatus routePointsStatusFromJson(Object? value) {
  return switch (value) {
    'awarded' => RoutePointsStatus.awarded,
    'held' => RoutePointsStatus.held,
    'rejected' => RoutePointsStatus.rejected,
    _ => RoutePointsStatus.none,
  };
}

class RouteExecutionRouting {
  const RouteExecutionRouting({
    this.provider,
    this.synthetic = false,
    this.qualityStatus = 'unknown',
    this.warnings = const [],
    this.totalDurationSeconds,
    this.movementDurationSeconds,
    this.visitDurationMinutes,
    this.distanceMeters,
    this.elevationGainMeters,
  });

  final String? provider;
  final bool synthetic;
  final String qualityStatus;
  final List<String> warnings;
  final int? totalDurationSeconds;
  final int? movementDurationSeconds;
  final int? visitDurationMinutes;
  final int? distanceMeters;
  final int? elevationGainMeters;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'synthetic': synthetic,
    'quality_status': qualityStatus,
    'warnings': warnings,
    'total_duration_seconds': totalDurationSeconds,
    'movement_duration_seconds': movementDurationSeconds,
    'visit_duration_minutes': visitDurationMinutes,
    'distance_meters': distanceMeters,
    'elevation_gain_meters': elevationGainMeters,
  };

  factory RouteExecutionRouting.fromJson(Map<String, dynamic> json) {
    final warnings = json['warnings'] is List
        ? (json['warnings'] as List).whereType<String>().take(32).toList()
        : const <String>[];
    return RouteExecutionRouting(
      provider: json['provider'] as String?,
      synthetic: json['synthetic'] as bool? ?? false,
      qualityStatus: json['quality_status'] as String? ?? 'unknown',
      warnings: warnings,
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toInt(),
      movementDurationSeconds: (json['movement_duration_seconds'] as num?)
          ?.toInt(),
      visitDurationMinutes: (json['visit_duration_minutes'] as num?)?.toInt(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      elevationGainMeters: (json['elevation_gain_meters'] as num?)?.toInt(),
    );
  }
}

class RouteExecution {
  const RouteExecution({
    required this.id,
    required this.routeName,
    required this.status,
    required this.startedAt,
    required this.totalStops,
    required this.completedStops,
    required this.requiredStops,
    required this.completedRequiredStops,
    required this.stops,
    this.routeId,
    this.routeCoverUrl,
    this.completedAt,
    this.cancelledAt,
    this.routing,
    this.awardedPoints = 0,
    this.pausedDurationSeconds = 0,
    this.pointsStatus = RoutePointsStatus.none,
    this.pointsReason,
    this.heldPoints = 0,
    this.antifraud,
    this.pausedAtLastMarkSeconds,
  });

  final String id;
  final String? routeId;
  final String routeName;
  final String? routeCoverUrl;
  final RouteExecutionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final RouteExecutionRouting? routing;

  /// Travel points granted on completion (`rewards.py:travel_points_for_effort`
  /// server-side) — zero until the run is completed.
  final int awardedPoints;

  /// Total time spent paused so far, so elapsed-time displays can net it out.
  final int pausedDurationSeconds;

  final RoutePointsStatus pointsStatus;

  /// Why a run earned less than the route is worth (`route_cooldown`,
  /// `daily_cap`); null for an ordinary completion.
  final String? pointsReason;
  final int heldPoints;

  /// Present only while the server enforces; gates every client-side hint.
  final RouteExecutionAntiFraud? antifraud;

  /// `pausedDurationSeconds` at the time of the last mark on this device, so
  /// the pace hint can net out pauses. Local only; null means unknown.
  final int? pausedAtLastMarkSeconds;
  final int totalStops;
  final int completedStops;
  final int requiredStops;
  final int completedRequiredStops;
  final List<RouteExecutionStop> stops;

  bool get isActive => status == RouteExecutionStatus.active;

  RouteExecution copyWith({
    RouteExecutionStatus? status,
    DateTime? completedAt,
    DateTime? cancelledAt,
    List<RouteExecutionStop>? stops,
    int? completedStops,
    int? completedRequiredStops,
    int? awardedPoints,
    int? pausedDurationSeconds,
    RoutePointsStatus? pointsStatus,
    String? pointsReason,
    int? heldPoints,
    RouteExecutionAntiFraud? antifraud,
    bool clearAntifraud = false,
    int? pausedAtLastMarkSeconds,
  }) => RouteExecution(
    id: id,
    routeId: routeId,
    routeName: routeName,
    routeCoverUrl: routeCoverUrl,
    status: status ?? this.status,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    routing: routing,
    totalStops: totalStops,
    completedStops: completedStops ?? this.completedStops,
    requiredStops: requiredStops,
    completedRequiredStops:
        completedRequiredStops ?? this.completedRequiredStops,
    stops: stops ?? this.stops,
    awardedPoints: awardedPoints ?? this.awardedPoints,
    pausedDurationSeconds: pausedDurationSeconds ?? this.pausedDurationSeconds,
    pointsStatus: pointsStatus ?? this.pointsStatus,
    pointsReason: pointsReason ?? this.pointsReason,
    heldPoints: heldPoints ?? this.heldPoints,
    antifraud: clearAntifraud ? null : antifraud ?? this.antifraud,
    pausedAtLastMarkSeconds:
        pausedAtLastMarkSeconds ?? this.pausedAtLastMarkSeconds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'route_id': routeId,
    'route_name': routeName,
    'awarded_points': awardedPoints,
    'paused_duration_seconds': pausedDurationSeconds,
    'points_status': pointsStatus.name,
    'points_reason': pointsReason,
    'held_points': heldPoints,
    'antifraud': antifraud?.toJson(),
    'paused_at_last_mark_seconds': pausedAtLastMarkSeconds,
    'route_cover_url': routeCoverUrl,
    'status': status.name,
    'started_at': startedAt.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
    'routing': routing?.toJson(),
    'total_stops': totalStops,
    'completed_stops': completedStops,
    'required_stops': requiredStops,
    'completed_required_stops': completedRequiredStops,
    'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
  };
  double get progress => totalStops == 0
      ? 0
      : (completedStops / totalStops).clamp(0, 1).toDouble();

  factory RouteExecution.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    return RouteExecution(
      id: json['id'] as String,
      routeId: json['route_id'] as String?,
      routeName: json['route_name'] as String? ?? 'Маршрут',
      routeCoverUrl: json['route_cover_url'] as String?,
      status: routeExecutionStatusFromJson(json['status']),
      startedAt: _date(json['started_at']) ?? DateTime.now(),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      routing: json['routing'] is Map
          ? RouteExecutionRouting.fromJson(
              Map<String, dynamic>.from(json['routing'] as Map),
            )
          : null,
      totalStops: (json['total_stops'] as num?)?.toInt() ?? 0,
      completedStops: (json['completed_stops'] as num?)?.toInt() ?? 0,
      requiredStops: (json['required_stops'] as num?)?.toInt() ?? 0,
      completedRequiredStops:
          (json['completed_required_stops'] as num?)?.toInt() ?? 0,
      awardedPoints: (json['awarded_points'] as num?)?.toInt() ?? 0,
      pausedDurationSeconds:
          (json['paused_duration_seconds'] as num?)?.toInt() ?? 0,
      pointsStatus: routePointsStatusFromJson(json['points_status']),
      pointsReason: json['points_reason'] as String?,
      heldPoints: (json['held_points'] as num?)?.toInt() ?? 0,
      antifraud: json['antifraud'] is Map
          ? RouteExecutionAntiFraud.fromJson(
              Map<String, dynamic>.from(json['antifraud'] as Map),
            )
          : null,
      pausedAtLastMarkSeconds: (json['paused_at_last_mark_seconds'] as num?)
          ?.toInt(),
      stops: rawStops is List
          ? rawStops
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (item) => RouteExecutionStop.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

DateTime? _date(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

int? _positiveInt(Object? value) {
  final parsed = (value as num?)?.toInt();
  return parsed != null && parsed > 0 ? parsed : null;
}
