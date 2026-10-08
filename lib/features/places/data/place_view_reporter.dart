import 'dart:async';

import 'package:dio/dio.dart';

/// Reports an opened place card to the server, which counts it towards the
/// place's popularity (spec 19).
///
/// The server keeps one row per person, place and day, so this sends at most
/// one request per place and day too. A failed request is forgotten: the
/// next time the card opens it is tried again, and nothing is shown to the
/// person either way.
class PlaceViewReporter {
  PlaceViewReporter(
    this._dio, {
    required this.isEnabled,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Dio _dio;

  /// False for a guest and for mock data: there is nobody to count.
  final bool Function() isEnabled;
  final DateTime Function() _now;
  final Set<String> _reported = {};

  void report(String placeId) {
    if (!isEnabled()) {
      return;
    }
    final day = _now().toUtc();
    final key = '$placeId|${day.year}-${day.month}-${day.day}';
    if (!_reported.add(key)) {
      return;
    }
    unawaited(_send(placeId, key));
  }

  Future<void> _send(String placeId, String key) async {
    try {
      await _dio.post<void>('/api/v1/places/$placeId/view');
    } on DioException {
      _reported.remove(key);
    }
  }
}
