import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

// BACKEND-42: «Пара часов» and «Полдня» before the whole days.

void main() {
  test('durations go to the server under its names', () {
    expect(RouteDurationOption.h2.api, 'h2');
    expect(RouteDurationOption.halfDay.api, 'half_day');
    expect(RouteDurationOption.d1_2.api, 'd1_2');
    expect(RouteDurationOption.values.first, RouteDurationOption.h2);
  });

  test('server names come back, an unknown one falls back to 3-5 days', () {
    expect(
      RouteDurationOption.fromApi('half_day'),
      RouteDurationOption.halfDay,
    );
    expect(RouteDurationOption.fromApi('d7plus'), RouteDurationOption.d7plus);
    expect(RouteDurationOption.fromApi('weeks'), RouteDurationOption.d3_5);
    expect(RouteDurationOption.fromApi(null), RouteDurationOption.d3_5);
  });
}
