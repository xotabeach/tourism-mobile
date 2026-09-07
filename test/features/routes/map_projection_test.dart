import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';

void main() {
  test('matches the pixel offsets observed on a real 2GIS static raster', () {
    // Probe run against the live static API: center (44.5, 34.1) at zoom 14 in
    // a 400x400 viewport put markers at x=200 (center), x=300 (+100px east)
    // and x=50 (-150px west), all on the vertical centre line.
    const zoom = 14;
    final world = MapProjection.tileSize * math.pow(2, zoom).toDouble();
    final degPerPx = 360.0 / world;
    const projection = MapProjection(
      centerLat: 44.5,
      centerLng: 34.1,
      zoom: zoom,
      size: Size(400, 400),
    );

    final center = projection.toPixel(44.5, 34.1);
    expect(center.dx, closeTo(200, 0.01));
    expect(center.dy, closeTo(200, 0.01));

    final east = projection.toPixel(44.5, 34.1 + degPerPx * 100);
    expect(east.dx, closeTo(300, 0.01));
    expect(east.dy, closeTo(200, 0.01));

    final west = projection.toPixel(44.5, 34.1 - degPerPx * 150);
    expect(west.dx, closeTo(50, 0.01));
  });

  test('fit keeps every point inside the padded viewport', () {
    const size = Size(360, 220);
    const padding = 56.0;
    final points = [
      (lat: 44.4952, lng: 34.1664),
      (lat: 44.4199, lng: 34.0558),
      (lat: 44.5100, lng: 34.2000),
    ];

    final projection = MapProjection.fit(
      points: points,
      size: size,
      padding: padding,
    );

    expect(projection, isNotNull);
    for (final point in points) {
      final pixel = projection!.toPixel(point.lat, point.lng);
      expect(pixel.dx, greaterThanOrEqualTo(padding - 1));
      expect(pixel.dx, lessThanOrEqualTo(size.width - padding + 1));
      expect(pixel.dy, greaterThanOrEqualTo(padding - 1));
      expect(pixel.dy, lessThanOrEqualTo(size.height - padding + 1));
    }
  });

  test('fit returns null without points or viewport', () {
    expect(
      MapProjection.fit(points: const [], size: const Size(300, 200)),
      isNull,
    );
    expect(
      MapProjection.fit(points: [(lat: 44.5, lng: 34.1)], size: Size.zero),
      isNull,
    );
  });

  group('completedFraction', () {
    // Five evenly-spaced points along a straight line — index i sits at
    // fraction i/4 of the route.
    final coordinates = [
      for (var i = 0; i <= 4; i++) (lat: 44.0 + i * 0.1, lng: 34.0 + i * 0.1),
    ];

    test('0 at the very start of the route', () {
      final fraction = MapProjection.completedFraction(
        coordinates: coordinates,
        reference: coordinates.first,
      );
      expect(fraction, 0);
    });

    test('1 at the very end of the route', () {
      final fraction = MapProjection.completedFraction(
        coordinates: coordinates,
        reference: coordinates.last,
      );
      expect(fraction, 1);
    });

    test('a midpoint stop lands at its own index fraction', () {
      final fraction = MapProjection.completedFraction(
        coordinates: coordinates,
        reference: coordinates[2],
      );
      expect(fraction, closeTo(0.5, 1e-9));
    });

    test('snaps to the nearest point for an off-path reference', () {
      // Closer to index 3 (lat 44.3) than index 2 (lat 44.2) or 4 (lat 44.4).
      final fraction = MapProjection.completedFraction(
        coordinates: coordinates,
        reference: (lat: 44.32, lng: 34.32),
      );
      expect(fraction, closeTo(0.75, 1e-9));
    });

    test('0 for fewer than two coordinates', () {
      expect(
        MapProjection.completedFraction(
          coordinates: const [],
          reference: (lat: 44.5, lng: 34.1),
        ),
        0,
      );
      expect(
        MapProjection.completedFraction(
          coordinates: [coordinates.first],
          reference: (lat: 44.5, lng: 34.1),
        ),
        0,
      );
    });
  });
}
