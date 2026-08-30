import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Web Mercator projection for 2GIS static map rasters.
///
/// The static API renders standard 256px-per-tile Web Mercator, so given the
/// same center/zoom the backend requested, the app can place its own pins on
/// the image with plain math instead of relying on the provider's baked-in
/// markers (which cannot be tapped and are styled by the vendor).
class MapProjection {
  const MapProjection({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.size,
  });

  static const double tileSize = 256;
  static const int minZoom = 1;
  static const int maxZoom = 18;

  final double centerLat;
  final double centerLng;
  final int zoom;

  /// Logical (CSS-pixel) size of the map viewport, matching the `s=WxH`
  /// requested from the provider — not the retina pixel size of the file.
  final Size size;

  double get _worldSize => tileSize * math.pow(2, zoom).toDouble();

  static double _worldX(double lng, double worldSize) =>
      (lng + 180) / 360 * worldSize;

  static double _worldY(double lat, double worldSize) {
    final clamped = lat.clamp(-85.05112878, 85.05112878);
    final rad = clamped * math.pi / 180;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) /
        2 *
        worldSize;
  }

  /// Pixel offset of a coordinate inside the rendered map.
  Offset toPixel(double lat, double lng) {
    final world = _worldSize;
    final dx = _worldX(lng, world) - _worldX(centerLng, world) + size.width / 2;
    final dy = _worldY(lat, world) - _worldY(centerLat, world) + size.height / 2;
    return Offset(dx, dy);
  }

  /// Projection that fits every point inside [size], with [padding] logical
  /// pixels of breathing room so pins near the edge are not clipped.
  ///
  /// Returns null when there is nothing to show or the viewport has no area.
  static MapProjection? fit({
    required List<({double lat, double lng})> points,
    required Size size,
    double padding = 56,
  }) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return null;

    final usableWidth = math.max(size.width - padding * 2, 1.0);
    final usableHeight = math.max(size.height - padding * 2, 1.0);

    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLng = points.first.lng;
    var maxLng = points.first.lng;
    for (final point in points) {
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
      minLng = math.min(minLng, point.lng);
      maxLng = math.max(maxLng, point.lng);
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Largest zoom whose projected span still fits the viewport.
    var best = minZoom;
    for (var zoom = maxZoom; zoom >= minZoom; zoom--) {
      final world = tileSize * math.pow(2, zoom).toDouble();
      final spanX = (_worldX(maxLng, world) - _worldX(minLng, world)).abs();
      // Latitude grows northwards while world Y grows southwards.
      final spanY = (_worldY(minLat, world) - _worldY(maxLat, world)).abs();
      if (spanX <= usableWidth && spanY <= usableHeight) {
        best = zoom;
        break;
      }
    }
    return MapProjection(
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: best,
      size: size,
    );
  }
}
