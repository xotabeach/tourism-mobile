import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

// Regression: route cards used to print a fixed ['Горы','С детьми','Пешком']
// tag row and «Продвинутый пешеход» under every non-editorial author, while
// the backend was already sending suitable_for_children / pets_allowed /
// seasonality (silently dropped by the model) and now sends the real rank.

RouteSummary _route({
  String? difficulty = 'moderate',
  String? transportMode = 'walk',
  bool? suitableForChildren,
  bool? petsAllowed,
  List<String> seasonality = const [],
  String? authorRankTitle,
}) {
  return RouteSummary(
    id: 'r1',
    name: 'Тропа',
    slug: 'tropa',
    shortDescription: null,
    stopsCount: 3,
    difficulty: difficulty,
    transportMode: transportMode,
    suitableForChildren: suitableForChildren,
    petsAllowed: petsAllowed,
    seasonality: seasonality,
    authorRankTitle: authorRankTitle,
  );
}

void main() {
  group('routeTagLabels', () {
    test('falls back to transport and difficulty when nothing else is set', () {
      expect(routeTagLabels(_route()), ['Пешком', 'Средний']);
    });

    test('adds audience flags only when the backend says true', () {
      expect(
        routeTagLabels(_route(suitableForChildren: true, petsAllowed: true)),
        ['Пешком', 'Средний', 'С детьми', 'С питомцем'],
      );
      // Explicit false and unknown must both stay silent — claiming a route
      // is child-friendly when it is not is worse than saying nothing.
      expect(
        routeTagLabels(_route(suitableForChildren: false, petsAllowed: false)),
        ['Пешком', 'Средний'],
      );
      expect(routeTagLabels(_route()), ['Пешком', 'Средний']);
    });

    test('season comes last so the first three chips stay informative', () {
      final tags = routeTagLabels(
        _route(suitableForChildren: true, seasonality: const ['summer']),
      );
      expect(tags.take(3), ['Пешком', 'Средний', 'С детьми']);
      expect(tags.last, 'Летом');
    });
  });

  group('seasonalityLabel', () {
    test('is null when there is nothing worth showing', () {
      expect(seasonalityLabel(const []), isNull);
      expect(seasonalityLabel(const ['неизвестно']), isNull);
    });

    test('collapses a full year of seasons into one chip', () {
      expect(
        seasonalityLabel(const ['winter', 'spring', 'summer', 'autumn']),
        'Круглый год',
      );
      expect(seasonalityLabel(const ['all_year']), 'Круглый год');
      expect(seasonalityLabel(const ['year_round']), 'Круглый год');
    });

    test('joins a partial season list', () {
      expect(seasonalityLabel(const ['summer', 'autumn']), 'Летом / Осенью');
    });

    test('treats autumn spellings as one season, not two', () {
      expect(seasonalityLabel(const ['autumn', 'fall']), 'Осенью');
    });
  });

  group('authorSubtitle', () {
    test('shows the real travel rank when the route has an owner', () {
      expect(
        authorSubtitle(_route(authorRankTitle: 'Легенда Крыма')),
        'Легенда Крыма',
      );
    });

    test('falls back to transport for editorial routes without a rank', () {
      expect(authorSubtitle(_route(transportMode: 'car')), 'На авто');
      expect(authorSubtitle(_route(authorRankTitle: '   ')), 'Пешком');
    });
  });

  group('RouteSummary.fromJson', () {
    test('keeps the fields the card needs instead of dropping them', () {
      final route = RouteSummary.fromJson(const {
        'id': 'r1',
        'name': 'Тропа',
        'slug': 'tropa',
        'short_description': null,
        'stops_count': 3,
        'suitable_for_children': true,
        'pets_allowed': false,
        'seasonality': ['summer', 'autumn'],
        'author_rank_title': 'Путешественник',
      });

      expect(route.suitableForChildren, isTrue);
      expect(route.petsAllowed, isFalse);
      expect(route.seasonality, ['summer', 'autumn']);
      expect(route.authorRankTitle, 'Путешественник');
    });

    test('stays safe when the backend omits them', () {
      final route = RouteSummary.fromJson(const {
        'id': 'r1',
        'name': 'Тропа',
        'slug': 'tropa',
        'short_description': null,
        'stops_count': 3,
      });

      expect(route.suitableForChildren, isNull);
      expect(route.seasonality, isEmpty);
      expect(route.authorRankTitle, isNull);
    });
  });
}
