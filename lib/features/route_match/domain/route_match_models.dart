import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class RouteMatchParams {
  const RouteMatchParams({
    required this.city,
    this.tripType,
    required this.duration,
    required this.people,
    required this.interests,
    required this.pace,
    this.season,
    this.transportMode,
    this.dayKind,
    this.budgetAmount,
    this.paidOk,
    this.withChildren,
    this.withPets,
    this.avoidCrowds,
    this.regionSlug = 'crimea',
  });

  final String city;
  final RouteTripType? tripType;
  final RouteDurationOption duration;
  final int people;
  final List<String> interests;
  final RoutePace pace;
  final String? season;
  final String? transportMode;
  final String? dayKind;
  final int? budgetAmount;
  final bool? paidOk;
  final bool? withChildren;
  final bool? withPets;
  final bool? avoidCrowds;
  final String regionSlug;

  Map<String, dynamic> toJson() => {
    'city': city,
    if (tripType != null) 'trip_type': tripType!.name,
    'duration': duration.name,
    'people': people,
    'interests': interests,
    'pace': pace.name,
    if (season != null) 'season': season,
    if (transportMode != null) 'transport_mode': transportMode,
    if (dayKind != null) 'day_kind': dayKind,
    if (budgetAmount != null) 'budget_amount': budgetAmount,
    if (paidOk != null) 'paid_ok': paidOk,
    if (withChildren != null) 'with_children': withChildren,
    if (withPets != null) 'with_pets': withPets,
    if (avoidCrowds != null) 'avoid_crowds': avoidCrowds,
    'region_slug': regionSlug,
  };
}

class RouteMatchHit {
  const RouteMatchHit({
    required this.route,
    required this.score,
    required this.band,
    required this.reasons,
  });

  final RouteSummary route;
  final double score;
  final String band;
  final List<String> reasons;

  factory RouteMatchHit.fromJson(Map<String, dynamic> json) {
    return RouteMatchHit(
      route: RouteSummary.fromJson(json['route'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      band: json['band'] as String,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

class RouteMatchResult {
  const RouteMatchResult({
    required this.strategy,
    required this.ideal,
    required this.close,
    required this.offerGenerate,
    required this.aiRerankEligible,
    required this.aiRerankApplied,
    required this.scoredTotal,
  });

  final String strategy;
  final List<RouteMatchHit> ideal;
  final List<RouteMatchHit> close;
  final bool offerGenerate;
  final bool aiRerankEligible;
  final bool aiRerankApplied;
  final int scoredTotal;

  List<RouteSummary> get idealRoutes =>
      ideal.map((hit) => hit.route).toList(growable: false);

  List<RouteSummary> get closeRoutes =>
      close.map((hit) => hit.route).toList(growable: false);

  factory RouteMatchResult.fromJson(Map<String, dynamic> json) {
    return RouteMatchResult(
      strategy: json['strategy'] as String,
      ideal: (json['ideal'] as List<dynamic>? ?? const [])
          .map((item) => RouteMatchHit.fromJson(item as Map<String, dynamic>))
          .toList(),
      close: (json['close'] as List<dynamic>? ?? const [])
          .map((item) => RouteMatchHit.fromJson(item as Map<String, dynamic>))
          .toList(),
      offerGenerate: json['offer_generate'] as bool? ?? false,
      aiRerankEligible: json['ai_rerank_eligible'] as bool? ?? false,
      aiRerankApplied: json['ai_rerank_applied'] as bool? ?? false,
      scoredTotal: json['scored_total'] as int? ?? 0,
    );
  }
}

class RouteQuotaSnapshot {
  const RouteQuotaSnapshot({
    required this.dailyUsed,
    required this.weeklyUsed,
    this.dailyRemaining,
    this.weeklyRemaining,
  });

  final int dailyUsed;
  final int weeklyUsed;
  final int? dailyRemaining;
  final int? weeklyRemaining;

  factory RouteQuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return RouteQuotaSnapshot(
      dailyUsed: json['daily_used'] as int? ?? 0,
      weeklyUsed: json['weekly_used'] as int? ?? 0,
      dailyRemaining: json['daily_remaining'] as int?,
      weeklyRemaining: json['weekly_remaining'] as int?,
    );
  }
}

class RouteProposalCardData {
  const RouteProposalCardData({
    required this.proposalId,
    required this.title,
    required this.stopsCount,
    required this.durationMinutes,
    this.coverUrl,
    this.placeIds = const [],
  });

  final String proposalId;
  final String title;
  final int stopsCount;
  final int durationMinutes;
  final String? coverUrl;
  final List<String> placeIds;

  factory RouteProposalCardData.fromJson(Map<String, dynamic> json) {
    return RouteProposalCardData(
      proposalId: json['proposal_id'] as String,
      title: json['title'] as String,
      stopsCount: json['stops_count'] as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      coverUrl: json['cover_url'] as String?,
      placeIds: (json['place_ids'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

sealed class RouteChatBlock {
  const RouteChatBlock();

  factory RouteChatBlock.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String?) {
      'place_chip' => PlaceChipBlock.fromJson(json),
      'route_proposal_card' => RouteProposalCardBlock.fromJson(json),
      'actions' => ActionsBlock.fromJson(json),
      _ => throw FormatException('Unknown block type: ${json['type']}'),
    };
  }

  static List<RouteChatBlock> parseAllowlist(List<dynamic>? raw) {
    final blocks = <RouteChatBlock>[];
    for (final item in raw ?? const []) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        blocks.add(RouteChatBlock.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    return blocks;
  }
}

final class PlaceChipBlock extends RouteChatBlock {
  const PlaceChipBlock({
    required this.placeId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.durationMinutes,
  });

  final String placeId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int? durationMinutes;

  factory PlaceChipBlock.fromJson(Map<String, dynamic> json) {
    return PlaceChipBlock(
      placeId: json['place_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
    );
  }
}

final class RouteProposalCardBlock extends RouteChatBlock {
  const RouteProposalCardBlock({required this.card});

  final RouteProposalCardData card;

  factory RouteProposalCardBlock.fromJson(Map<String, dynamic> json) {
    return RouteProposalCardBlock(card: RouteProposalCardData.fromJson(json));
  }
}

final class ActionsBlock extends RouteChatBlock {
  const ActionsBlock({required this.actions});

  final List<Map<String, String>> actions;

  factory ActionsBlock.fromJson(Map<String, dynamic> json) {
    final raw = json['actions'] as List<dynamic>? ?? const [];
    return ActionsBlock(
      actions: raw
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => {
              'id': item['id'] as String? ?? '',
              'label': item['label'] as String? ?? '',
            },
          )
          .toList(),
    );
  }
}

class RouteProposal {
  const RouteProposal({
    required this.proposalId,
    required this.status,
    required this.channel,
    required this.title,
    required this.assistantText,
    required this.placeIds,
    required this.durationMinutes,
    required this.blocks,
    required this.quota,
    this.coverUrl,
    this.routeId,
  });

  final String proposalId;
  final String status;
  final String channel;
  final String title;
  final String assistantText;
  final List<String> placeIds;
  final int durationMinutes;
  final String? coverUrl;
  final String? routeId;
  final List<RouteChatBlock> blocks;
  final RouteQuotaSnapshot quota;

  RouteProposalCardData get cardData {
    for (final block in blocks) {
      if (block is RouteProposalCardBlock) {
        return block.card;
      }
    }
    return RouteProposalCardData(
      proposalId: proposalId,
      title: title,
      stopsCount: placeIds.length,
      durationMinutes: durationMinutes,
      coverUrl: coverUrl,
      placeIds: placeIds,
    );
  }

  factory RouteProposal.fromJson(Map<String, dynamic> json) {
    return RouteProposal(
      proposalId: json['proposal_id'] as String,
      status: json['status'] as String,
      channel: json['channel'] as String? ?? 'form',
      title: json['title'] as String,
      assistantText: json['assistant_text'] as String,
      placeIds: (json['place_ids'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      coverUrl: json['cover_url'] as String?,
      routeId: json['route_id'] as String?,
      blocks: RouteChatBlock.parseAllowlist(json['blocks'] as List<dynamic>?),
      quota: RouteQuotaSnapshot.fromJson(
        json['quota'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class RouteGenerateResult {
  const RouteGenerateResult({
    required this.channel,
    required this.proposal,
    required this.persistedDraft,
    this.routeId,
  });

  final String channel;
  final String? routeId;
  final bool persistedDraft;
  final RouteProposal proposal;

  factory RouteGenerateResult.fromJson(Map<String, dynamic> json) {
    return RouteGenerateResult(
      channel: json['channel'] as String,
      routeId: json['route_id'] as String?,
      persistedDraft: json['persisted_draft'] as bool? ?? false,
      proposal: RouteProposal.fromJson(
        json['proposal'] as Map<String, dynamic>,
      ),
    );
  }
}

typedef RouteProposalResult = RouteProposal;

abstract class RouteMatchRepository {
  Future<RouteMatchResult> match(RouteMatchParams params);

  Future<RouteGenerateResult> generate({
    required String channel,
    required RouteMatchParams params,
  });

  Future<RouteProposalResult> acceptProposal(String id);

  Future<RouteProposalResult> rejectProposal(String id);

  Future<RoutePlanningSession> createSession(
    RouteMatchParams params, {
    List<String> confirmedFields = const [],
  });

  Future<RoutePlanningSession> closeSession(String sessionId);

  Future<RoutePlanningMessageResult> postMessage({
    required String sessionId,
    required String text,
    bool wantGenerate = false,
    String? actionId,
  });
}

class RoutePlanningSession {
  const RoutePlanningSession({
    required this.sessionId,
    required this.status,
    required this.constraints,
    required this.aiPlanningEnabled,
    this.confirmedFields = const [],
  });

  final String sessionId;
  final String status;
  final RouteMatchParams constraints;
  final bool aiPlanningEnabled;
  final List<String> confirmedFields;

  factory RoutePlanningSession.fromJson(Map<String, dynamic> json) {
    final rawConstraints =
        json['constraints'] as Map<String, dynamic>? ?? const {};
    return RoutePlanningSession(
      sessionId: json['session_id'] as String,
      status: json['status'] as String? ?? 'active',
      constraints: RouteMatchParams(
        city: rawConstraints['city'] as String? ?? 'Крым',
        duration: RouteDurationOption.values.firstWhere(
          (item) =>
              item.name == (rawConstraints['duration'] as String? ?? 'd3_5'),
          orElse: () => RouteDurationOption.d3_5,
        ),
        people: rawConstraints['people'] as int? ?? 2,
        interests: (rawConstraints['interests'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(),
        pace: RoutePace.values.firstWhere(
          (item) => item.name == (rawConstraints['pace'] as String? ?? 'calm'),
          orElse: () => RoutePace.calm,
        ),
        season: rawConstraints['season'] as String?,
        transportMode: rawConstraints['transport_mode'] as String?,
        dayKind: rawConstraints['day_kind'] as String?,
        budgetAmount: rawConstraints['budget_amount'] as int?,
        paidOk: rawConstraints['paid_ok'] as bool?,
        withChildren: rawConstraints['with_children'] as bool?,
        withPets: rawConstraints['with_pets'] as bool?,
        avoidCrowds: rawConstraints['avoid_crowds'] as bool?,
        regionSlug: rawConstraints['region_slug'] as String? ?? 'crimea',
      ),
      confirmedFields: (json['confirmed_fields'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      aiPlanningEnabled: json['ai_planning_enabled'] as bool? ?? false,
    );
  }
}

class RoutePlanningMessageResult {
  const RoutePlanningMessageResult({
    required this.messageId,
    required this.sessionId,
    required this.role,
    required this.text,
    required this.blocks,
    this.intent,
    this.proposal,
    this.provider,
    this.fallback = false,
    this.confirmedFields = const [],
    this.askField,
  });

  final String messageId;
  final String sessionId;
  final String role;
  final String text;
  final String? intent;
  final RouteProposal? proposal;
  final List<RouteChatBlock> blocks;
  final String? provider;
  final bool fallback;
  final List<String> confirmedFields;
  final String? askField;

  factory RoutePlanningMessageResult.fromJson(Map<String, dynamic> json) {
    final proposalJson = json['proposal'] as Map<String, dynamic>?;
    return RoutePlanningMessageResult(
      messageId: json['message_id'] as String,
      sessionId: json['session_id'] as String,
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      intent: json['intent'] as String?,
      proposal: proposalJson == null
          ? null
          : RouteProposal.fromJson(proposalJson),
      blocks: RouteChatBlock.parseAllowlist(json['blocks'] as List<dynamic>?),
      provider: json['provider'] as String?,
      fallback: json['fallback'] as bool? ?? false,
      confirmedFields: (json['confirmed_fields'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      askField: json['ask_field'] as String?,
    );
  }
}
