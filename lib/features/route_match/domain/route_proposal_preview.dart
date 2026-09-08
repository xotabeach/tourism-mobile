import 'package:tourism_mobile/features/routes/domain/route.dart';

class RouteProposalPreview {
  const RouteProposalPreview({
    required this.proposalId,
    required this.title,
    required this.stops,
    this.geometry,
    this.staticMapUrl,
    this.synthetic = true,
    this.days = const [],
    this.startDate,
    this.warnings = const [],
  });

  final String proposalId;
  final String title;
  final List<RouteStop> stops;
  final RouteGeometry? geometry;
  final String? staticMapUrl;
  final bool synthetic;
  final List<TripDay> days;
  final DateTime? startDate;
  final List<String> warnings;

  factory RouteProposalPreview.fromJson(Map<String, dynamic> json) {
    final plan = json['trip_plan'] as Map<String, dynamic>? ?? const {};
    return RouteProposalPreview(
      proposalId: json['proposal_id'] as String,
      title: json['title'] as String,
      stops: (json['stops'] as List<dynamic>)
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      geometry: json['geometry'] is Map<String, dynamic>
          ? RouteGeometry.fromJson(json['geometry'] as Map<String, dynamic>)
          : null,
      staticMapUrl: json['static_map_url'] as String?,
      synthetic: json['synthetic'] as bool? ?? true,
      days: (plan['days'] as List<dynamic>? ?? const [])
          .map((d) => TripDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      startDate: DateTime.tryParse(plan['start_date'] as String? ?? ''),
      warnings: (plan['warnings'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class TripDay {
  const TripDay({required this.day, required this.events});
  final int day;
  final List<TripEvent> events;
  factory TripDay.fromJson(Map<String, dynamic> json) => TripDay(
    day: json['day'] as int,
    events: (json['events'] as List<dynamic>)
        .map((e) => TripEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class TripEvent {
  const TripEvent({
    required this.kind,
    required this.title,
    required this.startMinute,
    required this.durationMinutes,
    this.placeId,
  });
  final String kind;
  final String title;
  final int startMinute;
  final int durationMinutes;
  final String? placeId;
  factory TripEvent.fromJson(Map<String, dynamic> json) => TripEvent(
    kind: json['kind'] as String,
    title: json['title'] as String,
    startMinute: json['start_minute'] as int,
    durationMinutes: json['duration_minutes'] as int,
    placeId: json['place_id'] as String?,
  );
  String get timeLabel {
    final h = startMinute ~/ 60;
    final m = startMinute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
