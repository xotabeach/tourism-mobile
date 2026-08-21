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

  test('RouteProposalCardData parses assembled extras safely', () {
    final card = RouteProposalCardData.fromJson({
      'proposal_id': 'p-2',
      'title': 'Собранный маршрут',
      'stops_count': 5,
      'duration_minutes': 360,
      'card_variant': 'assembled',
      'gallery_urls': [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ],
      'start_label': 'Симферополь',
      'start_subtitle': 'г. Симферополь',
      'finish_label': 'Ялта',
      'finish_subtitle': 'г. Ялта',
      'route_id': 'route-1',
      'locations': [
        {
          'id': 'loc-1',
          'title': 'Ласточкино гнездо',
          'subtitle': 'Гора',
          'index': 1,
        },
      ],
    });

    expect(card.cardVariant, RouteProposalCardVariant.assembled);
    expect(card.galleryUrls, hasLength(2));
    expect(card.startLabel, 'Симферополь');
    expect(card.routeId, 'route-1');
    expect(card.locations.single.title, 'Ласточкино гнездо');
  });

  test('CatalogMatchBlock and ActionsBlock layout parse from allowlist', () {
    final blocks = RouteChatBlock.parseAllowlist([
      {
        'type': 'catalog_match',
        'routes': [
          {
            'route_id': 'r-1',
            'title': 'Ялта · море',
            'rating': 4.8,
            'distance_km': 12.4,
            'tags': ['Пляж'],
          },
        ],
      },
      {
        'type': 'actions',
        'layout': 'stack',
        'actions': [
          {'id': 'build_custom_route', 'label': 'Собрать собственный маршрут'},
        ],
      },
    ]);

    expect(blocks, hasLength(2));
    expect(blocks.first, isA<CatalogMatchBlock>());
    expect((blocks.first as CatalogMatchBlock).routes.single.routeId, 'r-1');
    expect(blocks.last, isA<ActionsBlock>());
    expect((blocks.last as ActionsBlock).layout, ChatActionsLayout.stack);
  });
}
