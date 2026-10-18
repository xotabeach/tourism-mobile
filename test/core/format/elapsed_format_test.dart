import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/format/elapsed_format.dart';

void main() {
  test('minutes, hours and days as people read them', () {
    String f(int minutes) => formatElapsed(Duration(minutes: minutes));
    expect(f(0), '0 мин.');
    expect(f(45), '45 мин.');
    expect(f(59), '59 мин.');
    expect(f(60), '1 ч');
    expect(f(61), '1 ч 1 мин.');
    expect(f(252), '4 ч 12 мин.');
    expect(f(24 * 60 - 1), '23 ч 59 мин.');
    expect(f(24 * 60), '1 д');
    expect(f(5730), '3 д 23 ч');
    expect(formatElapsed(const Duration(seconds: -5)), '0 мин.');
    expect(
      formatElapsed(const Duration(minutes: 174), dot: false),
      '2 ч 54 мин',
    );
  });
}
