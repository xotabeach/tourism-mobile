import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

class ApiRouteMatchRepository implements RouteMatchRepository {
  ApiRouteMatchRepository(this._dio);

  final Dio _dio;

  @override
  Future<RouteMatchResult> match(RouteMatchParams params) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/match',
        data: params.toJson(),
      );
      return RouteMatchResult.fromJson(response.data!);
    });
  }

  @override
  Future<RouteGenerateResult> generate({
    required String channel,
    required RouteMatchParams params,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/generate',
        data: {'channel': channel, 'params': params.toJson()},
      );
      return RouteGenerateResult.fromJson(response.data!);
    });
  }

  @override
  Future<RouteProposalResult> acceptProposal(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/proposals/$id/accept',
      );
      return RouteProposal.fromJson(response.data!);
    });
  }

  @override
  Future<RouteProposalResult> rejectProposal(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/proposals/$id/reject',
      );
      return RouteProposal.fromJson(response.data!);
    });
  }

  @override
  Future<RoutePlanningSession> createSession(
    RouteMatchParams params, {
    List<String> confirmedFields = const [],
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions',
        data: {'params': params.toJson(), 'confirmed_fields': confirmedFields},
      );
      return RoutePlanningSession.fromJson(response.data!);
    });
  }

  @override
  Future<RoutePlanningSession> closeSession(String sessionId) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions/$sessionId/close',
      );
      return RoutePlanningSession.fromJson(response.data!);
    });
  }

  @override
  Future<RoutePlanningMessageResult> postMessage({
    required String sessionId,
    required String text,
    bool wantGenerate = false,
    String? actionId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions/$sessionId/messages',
        data: {
          'text': text,
          'want_generate': wantGenerate,
          'action_id': ?actionId,
        },
      );
      return RoutePlanningMessageResult.fromJson(response.data!);
    });
  }
}

/// Local fallback when DATA_SOURCE=mock (no backend).
class MockRouteMatchRepository implements RouteMatchRepository {
  int _mockSessionSeq = 0;

  @override
  Future<RouteMatchResult> match(RouteMatchParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final sample = RouteSummary(
      id: 'mock-match-1',
      name: '${params.city} · подборка',
      slug: 'mock-match',
      shortDescription: 'Демо-результат локального mock match',
      stopsCount: 4,
      estimatedDurationMinutes: 2400,
      difficulty: 'easy',
      transportMode: 'car',
      authorLabel: 'КрымТрип',
    );
    final hit = RouteMatchHit(
      route: sample,
      score: 0.72,
      band: 'ideal',
      reasons: const ['демо mock'],
    );
    return RouteMatchResult(
      strategy: 'algorithmic',
      ideal: [hit],
      close: const [],
      offerGenerate: false,
      aiRerankEligible: false,
      aiRerankApplied: false,
      scoredTotal: 1,
    );
  }

  @override
  Future<RouteGenerateResult> generate({
    required String channel,
    required RouteMatchParams params,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    const proposalId = 'mock-proposal-1';
    const routeId = 'mock-generated-route-1';
    final card = RouteProposalCardData(
      proposalId: proposalId,
      title: '${params.city} · ${params.interests.firstOrNull ?? "маршрут"}',
      stopsCount: 4,
      durationMinutes: 280,
      placeIds: const ['p1', 'p2', 'p3', 'p4'],
    );
    final proposal = RouteProposal(
      proposalId: proposalId,
      status: channel == 'form' ? 'accepted' : 'draft',
      channel: channel,
      title: card.title,
      assistantText:
          'Собрал черновик маршрута из ${params.city}. '
          'Можно создать маршрут, сохранить в черновик или уточнить параметры.',
      placeIds: card.placeIds,
      durationMinutes: card.durationMinutes,
      routeId: channel == 'form' ? routeId : null,
      blocks: [
        RouteProposalCardBlock(card: card),
        const ActionsBlock(
          actions: [
            {'id': 'accept_proposal', 'label': 'Создать маршрут'},
            {'id': 'save_draft', 'label': 'В черновик'},
            {'id': 'refine', 'label': 'Уточнить'},
          ],
        ),
      ],
      quota: const RouteQuotaSnapshot(dailyUsed: 1, weeklyUsed: 1),
    );
    return RouteGenerateResult(
      channel: channel,
      routeId: channel == 'form' ? routeId : null,
      persistedDraft: channel == 'form',
      proposal: proposal,
    );
  }

  @override
  Future<RouteProposalResult> acceptProposal(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return RouteProposal(
      proposalId: id,
      status: 'accepted',
      channel: 'chat',
      title: 'Mock маршрут',
      assistantText: 'Маршрут создан.',
      placeIds: const ['p1', 'p2'],
      durationMinutes: 180,
      routeId: 'mock-generated-route-1',
      blocks: const [],
      quota: const RouteQuotaSnapshot(dailyUsed: 1, weeklyUsed: 1),
    );
  }

  @override
  Future<RouteProposalResult> rejectProposal(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return RouteProposal(
      proposalId: id,
      status: 'rejected',
      channel: 'chat',
      title: 'Mock маршрут',
      assistantText: 'Предложение отклонено.',
      placeIds: const ['p1', 'p2'],
      durationMinutes: 180,
      blocks: const [],
      quota: const RouteQuotaSnapshot(dailyUsed: 1, weeklyUsed: 1),
    );
  }

  @override
  Future<RoutePlanningSession> createSession(
    RouteMatchParams params, {
    List<String> confirmedFields = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _mockSessionSeq += 1;
    return RoutePlanningSession(
      sessionId: 'mock-session-$_mockSessionSeq',
      status: 'active',
      constraints: params,
      confirmedFields: confirmedFields,
      aiPlanningEnabled: false,
    );
  }

  @override
  Future<RoutePlanningSession> closeSession(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return RoutePlanningSession(
      sessionId: sessionId,
      status: 'closed',
      constraints: const RouteMatchParams(
        city: 'Крым',
        duration: RouteDurationOption.d3_5,
        people: 2,
        interests: [],
        pace: RoutePace.calm,
      ),
      confirmedFields: const [],
      aiPlanningEnabled: false,
    );
  }

  @override
  Future<RoutePlanningMessageResult> postMessage({
    required String sessionId,
    required String text,
    bool wantGenerate = false,
    String? actionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (wantGenerate ||
        actionId == 'want_generate' ||
        text.toLowerCase().contains('подбери маршрут') ||
        text.toLowerCase().trim() == 'давай') {
      final generated = await generate(
        channel: 'chat',
        params: const RouteMatchParams(
          city: 'Ялта',
          duration: RouteDurationOption.d3_5,
          people: 2,
          interests: ['Пляж'],
          pace: RoutePace.calm,
        ),
      );
      return RoutePlanningMessageResult(
        messageId: 'mock-msg-gen',
        sessionId: sessionId,
        role: 'assistant',
        text: generated.proposal.assistantText,
        intent: 'generate',
        proposal: generated.proposal,
        blocks: generated.proposal.blocks,
        provider: 'deterministic_generate',
      );
    }
    final lowered = text.toLowerCase();
    var actions = <Map<String, String>>[
      {'id': 'want_generate', 'label': 'Подбери маршрут'},
      {'id': 'pace_calm', 'label': 'Хочу спокойно'},
      {'id': 'pace_active', 'label': 'Хочу активно'},
    ];
    var reply =
        'Понял: «$text». Уточните параметры поездки или нажмите «Подбери маршрут».';
    var askField = 'pace';
    if (actionId == 'transport_car' ||
        actionId == 'transport_public' ||
        lowered.contains('транспорт') ||
        lowered.contains('машин')) {
      actions = const [
        {'id': 'transport_car', 'label': 'На машине'},
        {'id': 'transport_public', 'label': 'Общественный транспорт'},
        {'id': 'transport_walk', 'label': 'Пешком'},
        {'id': 'want_generate', 'label': 'Подбери маршрут'},
      ];
      reply =
          'Принято. Подскажите, вы планируете поездку на машине, '
          'общественным транспортом или пешком?';
      askField = 'transport_mode';
    } else if (actionId?.startsWith('pace_') == true ||
        lowered.contains('спокойн') ||
        lowered.contains('активн')) {
      actions = const [
        {'id': 'pace_calm', 'label': 'Хочу спокойно'},
        {'id': 'pace_moderate', 'label': 'Умеренный темп'},
        {'id': 'pace_active', 'label': 'Хочу активно'},
        {'id': 'want_generate', 'label': 'Подбери маршрут'},
      ];
      reply = 'Какой темп вам ближе — спокойный, умеренный или активный?';
      askField = 'pace';
    } else if (actionId?.startsWith('interest_') == true ||
        lowered.contains('гор') ||
        lowered.contains('мор')) {
      actions = const [
        {'id': 'interest_sea', 'label': 'Больше моря'},
        {'id': 'interest_mountains', 'label': 'Больше гор'},
        {'id': 'interest_romance', 'label': 'Романтика'},
        {'id': 'want_generate', 'label': 'Подбери маршрут'},
      ];
      reply = 'Что важнее — море, горы или романтика?';
      askField = 'interests';
    }
    return RoutePlanningMessageResult(
      messageId: 'mock-msg-1',
      sessionId: sessionId,
      role: 'assistant',
      text: reply,
      intent: 'on_topic_travel',
      askField: askField,
      blocks: [ActionsBlock(actions: actions)],
      provider: 'mock',
      fallback: true,
    );
  }
}
