enum RouteExecutionStatus { active, completed, cancelled }

RouteExecutionStatus routeExecutionStatusFromJson(Object? value) {
  return switch (value) {
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

  bool get isCompleted => completedAt != null;

  RouteExecutionStop copyWith({DateTime? completedAt}) => RouteExecutionStop(
    id: id,
    position: position,
    placeName: placeName,
    isOptional: isOptional,
    routeStopId: routeStopId,
    placeId: placeId,
    lat: lat,
    lng: lng,
    completedAt: completedAt ?? this.completedAt,
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
    );
  }
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
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'route_id': routeId,
    'route_name': routeName,
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
