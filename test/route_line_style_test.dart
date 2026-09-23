import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';

void main() {
  test('every stored walking spelling is walked, vehicles are not', () {
    for (final mode in [
      'walk',
      'walking',
      ' Pedestrian ',
      'bicycle',
      null,
      '',
    ]) {
      expect(isWalkingMode(mode), isTrue, reason: '$mode');
    }
    for (final mode in ['car', 'driving', 'mixed', 'public_transport']) {
      expect(isWalkingMode(mode), isFalse, reason: mode);
    }
  });

  test('a dashed line keeps its length in dashes with gaps between', () {
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0)
      ..lineTo(100, 70);
    final dashes = dashedPath(line).computeMetrics().toList();
    // 170 px at 10 on, 7 off: ten full periods.
    expect(dashes, hasLength(10));
    final drawn = dashes.fold<double>(0, (sum, m) => sum + m.length);
    expect(drawn, closeTo(100, 0.5));
  });
}
