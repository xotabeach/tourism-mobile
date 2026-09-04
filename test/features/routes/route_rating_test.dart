import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/format/rating_format.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

import '../../support/test_overrides.dart';

RouteSummary _route({double? ratingAverage, int ratingCount = 0}) {
  return RouteSummary(
    id: 'route-1',
    name: 'Тропа Голицына',
    slug: 'golitsyn',
    shortDescription: 'Вдоль моря',
    stopsCount: 4,
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
  );
}

Future<void> _pumpCard(WidgetTester tester, RouteSummary route) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 320,
            child: RouteHeroCard(route: route, height: 320),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('rating format', () {
    test('uses a comma and one decimal', () {
      expect(formatRatingAverage(4.5), '4,5');
      expect(formatRatingAverage(5), '5,0');
      expect(formatRatingAverage(null), '');
    });

    test('pairs the average with how many gave it', () {
      expect(formatRatingWithCount(4.3, 12), '4,3 (12)');
      // No ratings means no number to show at all.
      expect(formatRatingWithCount(null, 0), '');
      expect(formatRatingWithCount(4.3, 0), '');
    });

    test('declines the count for the semantic label', () {
      expect(ratingCountLabel(1), '1 оценка');
      expect(ratingCountLabel(3), '3 оценки');
      expect(ratingCountLabel(5), '5 оценок');
      expect(ratingCountLabel(11), '11 оценок');
      expect(ratingCountLabel(21), '21 оценка');
      expect(ratingCountLabel(112), '112 оценок');
    });
  });

  testWidgets('a rated route shows its real average', (tester) async {
    await _pumpCard(tester, _route(ratingAverage: 4.3, ratingCount: 12));
    expect(find.text('4,3'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('an unrated route shows no star at all', (tester) async {
    // Not "0,0" and not an empty star: either reads as "bad route", which
    // would be a lie about one nobody has rated yet.
    await _pumpCard(tester, _route());
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  test('the fake name-derived rating is gone for good', () {
    // The card used to print '4,${9 - (route.name.length % 3)}', so every
    // route in the catalogue scored 4.7, 4.8 or 4.9 (replaced 2026-09-04).
    final source = File(
      'lib/features/routes/presentation/widgets/route_hero_card.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('route.name.length % 3')));
    expect(source, contains('formatRatingAverage'));
  });
}
