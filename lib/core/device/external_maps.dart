import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a coordinate to whatever maps the device actually has.
///
/// The app draws its own maps as static rasters, so "проложить маршрут" can
/// only mean "open this point somewhere that does navigation". Each platform
/// has a scheme its own maps answer, and both fall back to a plain web link
/// so a device without a maps app still lands somewhere useful.
abstract final class ExternalMaps {
  /// Candidate links for [lat]/[lng], best first.
  ///
  /// Pure so the ordering can be tested without launching anything.
  @visibleForTesting
  static List<Uri> candidates({
    required double lat,
    required double lng,
    required String label,
    required TargetPlatform platform,
  }) {
    final point = '$lat,$lng';
    final query = Uri.encodeComponent(label.trim().isEmpty ? point : label);
    return switch (platform) {
      TargetPlatform.iOS => [
        Uri.parse('maps://?ll=$point&q=$query'),
        Uri.parse('https://maps.apple.com/?ll=$point&q=$query'),
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$point'),
      ],
      TargetPlatform.android => [
        // geo: is the Android intent every maps app registers, so the user's
        // own default answers instead of whatever we happened to name.
        Uri.parse('geo:$point?q=$point($query)'),
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$point'),
      ],
      _ => [Uri.parse('https://www.google.com/maps/search/?api=1&query=$point')],
    };
  }

  /// Opens the point, returning false when nothing could handle it.
  static Future<bool> open({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final platform = defaultTargetPlatform;
    for (final uri in candidates(
      lat: lat,
      lng: lng,
      label: label,
      platform: platform,
    )) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } on Object {
        // A scheme this device has no handler for throws rather than
        // returning false; try the next candidate.
        continue;
      }
    }
    return false;
  }
}
