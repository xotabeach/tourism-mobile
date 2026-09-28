import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/application/route_match_notifier.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';

void main() {
  test('a comparison block is parsed into the figures of each route', () {
    // FRONTEND-46: «сравни» answers carry their figures as a block.
    final blocks = RouteChatBlock.parseAllowlist([
      {
        'type': 'route_comparison',
        'routes': [
          {
            'route_id': 'a',
            'title': 'Ай-Петри',
            'distance_km': 51.0,
            'duration_minutes': 420,
            'transport_label': 'Смешанный',
            'difficulty_label': 'Сложный',
            'difficulty_level': 3,
            'stops_count': 6,
            'badges': <String>[],
          },
          {
            'route_id': 'b',
            'title': 'Набережная',
            'distance_km': 4.2,
            'badges': ['Короче всех'],
          },
          {'route_id': '', 'title': 'Без id'},
        ],
      },
    ]);

    final routes = comparisonFromBlocks(blocks);
    expect(routes.map((route) => route.routeId), ['a', 'b']);
    expect(routes.first.durationMinutes, 420);
    expect(routes.first.difficultyLevel, 3);
    expect(routes.last.durationMinutes, isNull);
    expect(routes.last.badges, ['Короче всех']);
  });

  test('a single route is not a comparison', () {
    final blocks = RouteChatBlock.parseAllowlist([
      {
        'type': 'route_comparison',
        'routes': [
          {'route_id': 'a', 'title': 'Один'},
        ],
      },
    ]);
    expect(comparisonFromBlocks(blocks), isEmpty);
  });
}
