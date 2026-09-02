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

  RouteMatchParams copyWith({
    String? city,
    RouteTripType? tripType,
    RouteDurationOption? duration,
    int? people,
    List<String>? interests,
    RoutePace? pace,
    String? season,
    String? transportMode,
    String? dayKind,
    int? budgetAmount,
    bool? paidOk,
    bool? withChildren,
    bool? withPets,
    bool? avoidCrowds,
    String? regionSlug,
  }) {
    return RouteMatchParams(
      city: city ?? this.city,
      tripType: tripType ?? this.tripType,
      duration: duration ?? this.duration,
      people: people ?? this.people,
      interests: interests ?? this.interests,
      pace: pace ?? this.pace,
      season: season ?? this.season,
      transportMode: transportMode ?? this.transportMode,
      dayKind: dayKind ?? this.dayKind,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      paidOk: paidOk ?? this.paidOk,
      withChildren: withChildren ?? this.withChildren,
      withPets: withPets ?? this.withPets,
      avoidCrowds: avoidCrowds ?? this.avoidCrowds,
      regionSlug: regionSlug ?? this.regionSlug,
    );
  }
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

enum RouteProposalCardVariant { catalog, assembled, compact }

RouteProposalCardVariant _parseCardVariant(String? raw) {
  return switch (raw) {
    'catalog' => RouteProposalCardVariant.catalog,
    'assembled' => RouteProposalCardVariant.assembled,
    _ => RouteProposalCardVariant.compact,
  };
}

class ProposalLocationItem {
  const ProposalLocationItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.index,
  });

  final String id;
  final String title;
  final String? subtitle;
  final int index;

  factory ProposalLocationItem.fromJson(Map<String, dynamic> json) {
    return ProposalLocationItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      index: json['index'] as int? ?? 1,
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
    this.rating,
    this.distanceKm,
    this.localityLabel,
    this.tags = const [],
    this.budgetLabel,
    this.difficultyLabel,
    this.primaryActionLabel = 'Пройти маршрут',
    this.cardVariant = RouteProposalCardVariant.compact,
    this.galleryUrls = const [],
    this.startLabel,
    this.startSubtitle,
    this.finishLabel,
    this.finishSubtitle,
    this.locations = const [],
    this.routeId,
  });

  final String proposalId;
  final String title;
  final int stopsCount;
  final int durationMinutes;
  final String? coverUrl;
  final List<String> placeIds;
  final double? rating;
  final double? distanceKm;
  final String? localityLabel;
  final List<String> tags;
  final String? budgetLabel;
  final String? difficultyLabel;
  final String primaryActionLabel;
  final RouteProposalCardVariant cardVariant;
  final List<String> galleryUrls;
  final String? startLabel;
  final String? startSubtitle;
  final String? finishLabel;
  final String? finishSubtitle;
  final List<ProposalLocationItem> locations;
  final String? routeId;

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
      rating: (json['rating'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      localityLabel: json['locality_label'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      budgetLabel: json['budget_label'] as String?,
      difficultyLabel: json['difficulty_label'] as String?,
      primaryActionLabel:
          json['primary_action_label'] as String? ?? 'Пройти маршрут',
      cardVariant: _parseCardVariant(json['card_variant'] as String?),
      galleryUrls: (json['gallery_urls'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      startLabel: json['start_label'] as String?,
      startSubtitle: json['start_subtitle'] as String?,
      finishLabel: json['finish_label'] as String?,
      finishSubtitle: json['finish_subtitle'] as String?,
      locations: (json['locations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProposalLocationItem.fromJson)
          .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
          .toList(growable: false),
      routeId: json['route_id'] as String?,
    );
  }
}

class CatalogRouteItem {
  const CatalogRouteItem({
    required this.routeId,
    required this.title,
    this.coverUrl,
    this.rating,
    this.distanceKm,
    this.localityLabel,
    this.tags = const [],
    this.budgetLabel,
    this.difficultyLabel,
    this.stopsCount = 0,
    this.durationMinutes = 0,
  });

  final String routeId;
  final String title;
  final String? coverUrl;
  final double? rating;
  final double? distanceKm;
  final String? localityLabel;
  final List<String> tags;
  final String? budgetLabel;
  final String? difficultyLabel;
  final int stopsCount;
  final int durationMinutes;

  factory CatalogRouteItem.fromJson(Map<String, dynamic> json) {
    return CatalogRouteItem(
      routeId: json['route_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      localityLabel: json['locality_label'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      budgetLabel: json['budget_label'] as String?,
      difficultyLabel: json['difficulty_label'] as String?,
      stopsCount: json['stops_count'] as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
    );
  }
}

sealed class RouteChatBlock {
  const RouteChatBlock();

  factory RouteChatBlock.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String?) {
      'place_chip' => PlaceChipBlock.fromJson(json),
      'route_proposal_card' => RouteProposalCardBlock.fromJson(json),
      'catalog_match' => CatalogMatchBlock.fromJson(json),
      'actions' => ActionsBlock.fromJson(json),
      'slider' => SliderBlock.fromJson(json),
      'toggle' => ToggleBlock.fromJson(json),
      'select' => SelectBlock.fromJson(json),
      'recommendation_card' => RecommendationCardBlock.fromJson(json),
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

enum ChatActionsLayout { wrap, stack, sheet }

ChatActionsLayout _parseActionsLayout(String? raw) {
  switch (raw) {
    case 'stack':
      return ChatActionsLayout.stack;
    case 'sheet':
      return ChatActionsLayout.sheet;
    default:
      return ChatActionsLayout.wrap;
  }
}

final class ActionsBlock extends RouteChatBlock {
  const ActionsBlock({
    required this.actions,
    this.layout = ChatActionsLayout.wrap,
    this.sheetTitle,
  });

  final List<Map<String, String>> actions;
  final ChatActionsLayout layout;
  final String? sheetTitle;

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
      layout: _parseActionsLayout(json['layout'] as String?),
      sheetTitle: json['sheet_title'] as String?,
    );
  }
}

final class CatalogMatchBlock extends RouteChatBlock {
  const CatalogMatchBlock({required this.routes});

  final List<CatalogRouteItem> routes;

  factory CatalogMatchBlock.fromJson(Map<String, dynamic> json) {
    final raw = json['routes'] as List<dynamic>? ?? const [];
    return CatalogMatchBlock(
      routes: raw
          .whereType<Map<String, dynamic>>()
          .map(CatalogRouteItem.fromJson)
          .where((item) => item.routeId.isNotEmpty && item.title.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class SliderBlock extends RouteChatBlock {
  const SliderBlock({
    required this.id,
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.step,
    this.value,
    this.unit,
  });

  final String id;
  final String label;
  final double minValue;
  final double maxValue;
  final double step;
  final double? value;
  final String? unit;

  factory SliderBlock.fromJson(Map<String, dynamic> json) {
    return SliderBlock(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      minValue: (json['min_value'] as num?)?.toDouble() ?? 0,
      maxValue: (json['max_value'] as num?)?.toDouble() ?? 1,
      step: (json['step'] as num?)?.toDouble() ?? 1,
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

final class ToggleBlock extends RouteChatBlock {
  const ToggleBlock({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final bool value;

  factory ToggleBlock.fromJson(Map<String, dynamic> json) {
    return ToggleBlock(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as bool? ?? false,
    );
  }
}

/// Один вариант в [SelectBlock]. `value` уходит агенту, `label` видит человек.
class SelectOptionItem {
  const SelectOptionItem({required this.value, required this.label});

  final String value;
  final String label;

  factory SelectOptionItem.fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String? ?? '';
    return SelectOptionItem(
      value: value,
      label: json['label'] as String? ?? value,
    );
  }
}

/// Выпадающий список внутри пузыря агента.
///
/// Сознательно общий, а не «выбор города»: агент присылает `select` с любым
/// набором вариантов, клиент про смысл поля ничего не знает и возвращает
/// выбранный `value` тем же путём, что значения слайдеров и переключателей.
/// Сегодня так спрашивается только стартовый город.
final class SelectBlock extends RouteChatBlock {
  const SelectBlock({
    required this.id,
    required this.label,
    required this.options,
    this.value,
    this.placeholder = 'Выберите вариант',
  });

  final String id;
  final String label;
  final List<SelectOptionItem> options;
  final String? value;
  final String placeholder;

  factory SelectBlock.fromJson(Map<String, dynamic> json) {
    final options = <SelectOptionItem>[];
    for (final item in json['options'] as List<dynamic>? ?? const []) {
      if (item is Map<String, dynamic>) {
        final option = SelectOptionItem.fromJson(item);
        if (option.value.isNotEmpty) {
          options.add(option);
        }
      }
    }
    return SelectBlock(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      options: options,
      value: json['value'] as String?,
      placeholder: json['placeholder'] as String? ?? 'Выберите вариант',
    );
  }
}

final class RecommendationCardBlock extends RouteChatBlock {
  const RecommendationCardBlock({
    required this.id,
    required this.title,
    required this.body,
    required this.acceptActionId,
    this.acceptLabel = 'Попробуем так',
  });

  final String id;
  final String title;
  final String body;
  final String acceptActionId;
  final String acceptLabel;

  factory RecommendationCardBlock.fromJson(Map<String, dynamic> json) {
    return RecommendationCardBlock(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      acceptActionId: json['accept_action_id'] as String? ?? '',
      acceptLabel: json['accept_label'] as String? ?? 'Попробуем так',
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

  Future<RoutePlanningSessionListResult> listSessions({
    int limit = 20,
    int offset = 0,
  });

  Future<RoutePlanningMessageListResult> listMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  });

  Future<RoutePlanningMessageResult> postMessage({
    required String sessionId,
    required String text,
    bool wantGenerate = false,
    String? actionId,
    Object? controlValue,
  });
}

class RoutePlanningSession {
  const RoutePlanningSession({
    required this.sessionId,
    required this.status,
    required this.constraints,
    required this.aiPlanningEnabled,
    this.confirmedFields = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String sessionId;
  final String status;
  final RouteMatchParams constraints;
  final bool aiPlanningEnabled;
  final List<String> confirmedFields;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class RoutePlanningSessionListResult {
  const RoutePlanningSessionListResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<RoutePlanningSession> items;
  final int total;
  final int limit;
  final int offset;

  factory RoutePlanningSessionListResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return RoutePlanningSessionListResult(
      items: itemsJson
          .map(
            (item) =>
                RoutePlanningSession.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      total: json['total'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? itemsJson.length,
      offset: json['offset'] as int? ?? 0,
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
    this.createdAt,
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

  /// Only present on stored (history) rows — a fresh reply from `postMessage`
  /// is timestamped locally instead (see `_nowTime()` at the call site).
  final DateTime? createdAt;

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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

/// A stored message row (`GET .../sessions/{id}/messages`) parses through
/// the exact same shape as a live reply — every field [RoutePlanningMessageResult]
/// reads defaults safely when absent (no `proposal`/`provider`/`fallback` in
/// the stored form), so history replay reuses it as-is instead of a second
/// model.
class RoutePlanningMessageListResult {
  const RoutePlanningMessageListResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<RoutePlanningMessageResult> items;
  final int total;
  final int limit;
  final int offset;

  factory RoutePlanningMessageListResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return RoutePlanningMessageListResult(
      items: itemsJson
          .map(
            (item) => RoutePlanningMessageResult.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      total: json['total'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? itemsJson.length,
      offset: json['offset'] as int? ?? 0,
    );
  }
}
