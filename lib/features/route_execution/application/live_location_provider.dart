import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// The device's live position while walking a route, or `null` when it is
/// unavailable for any reason (permission denied, location services off,
/// simulator/desktop with no provider). Every consumer must treat `null` as
/// "hide the live-position UI, fall back to the static view" — never as an
/// error to surface, since GPS is a soft hint everywhere it's used here.
final liveLocationProvider = StreamProvider.autoDispose<Position?>((ref) async* {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    yield null;
    return;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      // Redraw the marker/recompute distance every ~5m walked, not on every
      // GPS chip update — the stop pins themselves are metres apart.
      distanceFilter: 5,
    ),
  );
});
