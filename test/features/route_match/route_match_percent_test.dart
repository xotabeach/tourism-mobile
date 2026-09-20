import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_results_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

import '../../support/test_overrides.dart';

const _first = RouteSummary(
  id: 'm1',
  name: 'Ялта у моря',
  slug: 'm1',
  shortDescription: 'море',
  stopsCount: 3,
);
const _second = RouteSummary(
  id: 'm2',
  name: 'Другой вариант у моря',
  slug: 'm2',
  shortDescription: 'море',
  stopsCount: 3,
);

Map<String, dynamic> _hitJson(
  String id,
  String name,
  String band,
  int percent,
) => {
  'route': {'id': id, 'name': name, 'slug': id, 'stops_count': 3},
  'score': percent / 100,
  'band': band,
  'reasons': <String>[],
  'match_percent': percent,
  'mismatches': ['старт не совпал', 'другой темп'],
  'partial_data': band == 'close',
};

void main() {
  group('parsing', () {
    test('the new fields are read from a current backend', () {
      final result = RouteMatchResult.fromJson({
        'strategy': 'algorithmic',
        'ideal': [_hitJson('m1', 'A', 'ideal', 80)],
        'close': <Map<String, dynamic>>[],
        'hits': [
          _hitJson('m1', 'A', 'ideal', 80),
          _hitJson('m2', 'B', 'close', 45),
        ],
        'formula_version': 2,
        'offer_generate': false,
      });
      expect(result.formulaVersion, 2);
      expect(result.orderedHits, hasLength(2));
      final close = result.orderedHits.last;
      expect(close.matchPercent, 45);
      expect(close.partialData, isTrue);
      expect(close.mainMismatch, 'старт не совпал');
      expect(close.isIdeal, isFalse);
    });

    test('an older backend without hits falls back to the two bands', () {
      final result = RouteMatchResult.fromJson({
        'strategy': 'algorithmic',
        'ideal': [
          {
            'route': {'id': 'r1', 'name': 'A', 'slug': 'a', 'stops_count': 1},
            'score': 0.9,
            'band': 'ideal',
            'reasons': <String>[],
          },
        ],
        'close': [
          {
            'route': {'id': 'r2', 'name': 'B', 'slug': 'b', 'stops_count': 1},
            'score': 0.4,
            'band': 'close',
            'reasons': <String>[],
          },
        ],
        'offer_generate': false,
      });
      expect(result.hits, isEmpty);
      expect(result.orderedHits.map((hit) => hit.route.id), ['r1', 'r2']);
      expect(result.orderedHits.first.matchPercent, isNull);
      expect(result.formulaVersion, 1);
    });

    test('a chat card carries the percent snapshot, old ones do not', () {
      final withPercent = CatalogRouteItem.fromJson({
        'route_id': 'r',
        'title': 'T',
        'match_percent': 75,
        'main_mismatch': 'старт не совпал',
      });
      expect(withPercent.matchPercent, 75);
      expect(withPercent.mainMismatch, 'старт не совпал');
      final old = CatalogRouteItem.fromJson({'route_id': 'r', 'title': 'T'});
      expect(old.matchPercent, isNull);
    });

    test('explicit fields are sent only when the form provides them', () {
      const base = RouteMatchParams(
        duration: RouteDurationOption.d3_5,
        people: 2,
        interests: [],
        pace: RoutePace.calm,
      );
      expect(base.toJson().containsKey('explicit_fields'), isFalse);
      final chosen = base.copyWith(explicitFields: const ['duration']);
      expect(chosen.toJson()['explicit_fields'], ['duration']);
      final none = base.copyWith(explicitFields: const []);
      expect(none.toJson()['explicit_fields'], isEmpty);
    });
  });

  group('results screen', () {
    Future<void> pump(WidgetTester tester, RouteMatchResult result) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 1400);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      final container = ProviderContainer(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          lastRouteMatchResultProvider.overrideWith((ref) => result),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RouteMatchResultsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the percent and the main mismatch on each card', (
      tester,
    ) async {
      const ideal = RouteMatchHit(
        route: _first,
        score: 0.8,
        band: 'ideal',
        reasons: [],
        matchPercent: 80,
        mismatches: ['дольше, чем вы планировали'],
      );
      const close = RouteMatchHit(
        route: _second,
        score: 0.45,
        band: 'close',
        reasons: [],
        matchPercent: 45,
        mismatches: ['старт не совпал'],
        partialData: true,
      );
      await pump(
        tester,
        const RouteMatchResult(
          strategy: 'algorithmic',
          ideal: [ideal],
          close: [close],
          hits: [ideal, close],
          formulaVersion: 2,
          offerGenerate: false,
          aiRerankEligible: false,
          aiRerankApplied: false,
          scoredTotal: 2,
        ),
      );
      expect(find.text('Подходит на 80%'), findsOneWidget);
      expect(find.text('дольше, чем вы планировали'), findsOneWidget);
      expect(find.text('Подходит на 45% · по части данных'), findsOneWidget);
      expect(find.text('Идеально для вас:'), findsOneWidget);
      expect(find.text('Близки к вашему идеалу:'), findsOneWidget);
    });

    testWidgets(
      'a result from an older backend shows the cards without a percent',
      (tester) async {
        const hit = RouteMatchHit(
          route: _first,
          score: 0.8,
          band: 'ideal',
          reasons: [],
        );
        await pump(
          tester,
          const RouteMatchResult(
            strategy: 'algorithmic',
            ideal: [hit],
            close: [],
            offerGenerate: false,
            aiRerankEligible: false,
            aiRerankApplied: false,
            scoredTotal: 1,
          ),
        );
        expect(find.text('Ялта у моря'), findsOneWidget);
        expect(find.textContaining('Подходит на'), findsNothing);
      },
    );
  });
}
