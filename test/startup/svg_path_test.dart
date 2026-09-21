import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/startup/krymtrip_logo_data.dart';
import 'package:tourism_mobile/core/startup/svg_path.dart';

void main() {
  test('parses moves, lines, curves and close', () {
    final path = parseSvgPath('M10 10L20 10V30H10Z');
    expect(path.getBounds(), const Rect.fromLTRB(10, 10, 20, 30));

    final curve = parseSvgPath('M0 0C0 10 10 10 10 0');
    expect(curve.getBounds().left, 0);
    expect(curve.getBounds().right, 10);
  });

  test('numbers after M are implicit line-tos', () {
    final path = parseSvgPath('M0 0 10 0 10 10Z');
    expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('rejects commands it cannot draw', () {
    expect(() => parseSvgPath('M0 0A5 5 0 0 1 10 10'), throwsFormatException);
  });

  test('every path of the brand logo parses and fits the 209 x 224 frame', () {
    final bounds = [
      for (final data in krymtripLogoPathData) parseSvgPath(data).getBounds(),
    ];
    expect(bounds, hasLength(8));
    for (final b in bounds) {
      expect(b.isEmpty, isFalse);
      // Curves may overshoot the frame by a hair.
      expect(b.left, greaterThanOrEqualTo(-1));
      expect(b.top, greaterThanOrEqualTo(-1));
      expect(b.right, lessThanOrEqualTo(krymtripLogoSize.width + 1));
      expect(b.bottom, lessThanOrEqualTo(krymtripLogoSize.height + 1));
    }
  });
}
