import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

void main() {
  test('RouteMatchParams serializes allowlisted fields only', () {
    final json = const RouteMatchParams(
      city: 'Ялта',
      tripType: RouteTripType.rest,
      duration: RouteDurationOption.d3_5,
      people: 2,
      interests: ['Пляж', 'Природа'],
      pace: RoutePace.calm,
      season: 'лето',
      transportMode: 'car',
      dayKind: 'weekend',
      budgetAmount: 12000,
      paidOk: true,
      withChildren: true,
      avoidCrowds: true,
    ).toJson();

    expect(json['city'], 'Ялта');
    expect(json['trip_type'], 'rest');
    expect(json['duration'], 'd3_5');
    expect(json['pace'], 'calm');
    expect(json['interests'], ['Пляж', 'Природа']);
    expect(json['season'], 'лето');
    expect(json['transport_mode'], 'car');
    expect(json['day_kind'], 'weekend');
    expect(json['budget_amount'], 12000);
    expect(json['paid_ok'], isTrue);
    expect(json['with_children'], isTrue);
    expect(json['avoid_crowds'], isTrue);
    expect(json.containsKey('role'), isFalse);
  });

  test('RouteMatchResult parses ideal/close bands', () {
    final result = RouteMatchResult.fromJson({
      'strategy': 'algorithmic',
      'ideal': [
        {
          'route': {
            'id': 'r1',
            'name': 'Ялта день',
            'slug': 'yalta-day',
            'short_description': null,
            'stops_count': 3,
          },
          'score': 0.81,
          'band': 'ideal',
          'reasons': ['старт рядом с Ялта'],
        },
      ],
      'close': <Map<String, dynamic>>[],
      'offer_generate': false,
      'ai_rerank_eligible': false,
      'ai_rerank_applied': false,
      'scored_total': 5,
    });

    expect(result.ideal, hasLength(1));
    expect(result.ideal.first.route.name, 'Ялта день');
    expect(result.offerGenerate, isFalse);
    expect(result.strategy, 'algorithmic');
  });

  test('RouteGenerateResult parses proposal blocks allowlist', () {
    final result = RouteGenerateResult.fromJson({
      'channel': 'chat',
      'route_id': null,
      'persisted_draft': false,
      'proposal': {
        'proposal_id': 'p-1',
        'status': 'draft',
        'channel': 'chat',
        'title': 'Ялта · море',
        'assistant_text': 'Собрал черновик.',
        'place_ids': ['pl-1', 'pl-2'],
        'duration_minutes': 240,
        'blocks': [
          {
            'type': 'route_proposal_card',
            'proposal_id': 'p-1',
            'title': 'Ялта · море',
            'stops_count': 2,
            'duration_minutes': 240,
            'place_ids': ['pl-1', 'pl-2'],
          },
          {
            'type': 'actions',
            'actions': [
              {'id': 'accept_proposal', 'label': 'Создать маршрут'},
            ],
          },
          {'type': 'unknown_block', 'payload': 'ignored'},
        ],
        'quota': {'daily_used': 1, 'weekly_used': 2},
      },
    });

    expect(result.channel, 'chat');
    expect(result.proposal.cardData.stopsCount, 2);
    expect(result.proposal.blocks, hasLength(2));
    expect(result.proposal.blocks.last, isA<ActionsBlock>());
  });
}
