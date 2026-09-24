import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_execution/presentation/start_route_sheet.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

RouteDetail _route({
  int? minutes,
  int? meters,
  String? difficulty,
  int stopsCount = 0,
}) => RouteDetail(
  id: 'r',
  name: 'Маршрут',
  slug: 'r',
  shortDescription: null,
  description: null,
  stopsCount: stopsCount,
  estimatedDurationMinutes: minutes,
  distanceMeters: meters,
  difficulty: difficulty,
  media: const [],
  stops: const [],
);

void main() {
  test('summary lists the facts the route has', () {
    expect(
      startRouteFacts(
        _route(
          minutes: 150,
          meters: 12400,
          difficulty: 'moderate',
          stopsCount: 7,
        ),
      ),
      ['2 ч 30 мин', '12 км', '7 точек', 'Средний'],
    );
    expect(startRouteFacts(_route(minutes: 45, stopsCount: 1)), [
      '45 мин',
      '1 точка',
    ]);
    expect(startRouteFacts(_route(stopsCount: 3)), ['3 точки']);
    expect(startRouteFacts(_route()), isEmpty);
  });
}
