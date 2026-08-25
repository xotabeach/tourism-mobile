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
  Future<RoutePlanningSessionListResult> listSessions({
    int limit = 20,
    int offset = 0,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return RoutePlanningSessionListResult.fromJson(response.data!);
    });
  }

  @override
  Future<RoutePlanningMessageListResult> listMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions/$sessionId/messages',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return RoutePlanningMessageListResult.fromJson(response.data!);
    });
  }

  @override
  Future<RoutePlanningMessageResult> postMessage({
    required String sessionId,
    required String text,
    bool wantGenerate = false,
    String? actionId,
    Object? controlValue,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/route-builder/sessions/$sessionId/messages',
        data: {
          'text': text,
          'want_generate': wantGenerate,
          'action_id': ?actionId,
          'control_value': ?controlValue,
        },
      );
      return RoutePlanningMessageResult.fromJson(response.data!);
    });
  }
}

/// Local fallback when DATA_SOURCE=mock (no backend).
class MockRouteMatchRepository implements RouteMatchRepository {
  int _mockSessionSeq = 0;

  // Keyed insertion order = most-recent-last; listSessions reverses it so
  // the history screen (like the real API, ordered by updated_at desc)
  // shows the latest session first.
  final _mockSessions = <String, RoutePlanningSession>{
    'mock-session-history-1': const RoutePlanningSession(
      sessionId: 'mock-session-history-1',
      status: 'closed',
      constraints: RouteMatchParams(
        city: 'Ялта',
        duration: RouteDurationOption.d3_5,
        people: 2,
        interests: ['Море', 'Романтика'],
        pace: RoutePace.calm,
      ),
      aiPlanningEnabled: true,
    ),
  };
  final _mockMessages = <String, List<RoutePlanningMessageResult>>{
    'mock-session-history-1': const [
      RoutePlanningMessageResult(
        messageId: 'mock-hist-1',
        sessionId: 'mock-session-history-1',
        role: 'assistant',
        text: 'Здравствуйте! Подберём маршрут по Ялте?',
        blocks: [],
      ),
      RoutePlanningMessageResult(
        messageId: 'mock-hist-2',
        sessionId: 'mock-session-history-1',
        role: 'user',
        text: 'Подбери спокойный маршрут по Ялте на выходные',
        blocks: [],
      ),
      RoutePlanningMessageResult(
        messageId: 'mock-hist-3',
        sessionId: 'mock-session-history-1',
        role: 'assistant',
        text:
            'Собрал черновик маршрута из Ялты. Можно создать маршрут, '
            'сохранить в черновик или уточнить параметры.',
        blocks: [],
      ),
    ],
  };

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
            {'id': 'accept_proposal', 'label': 'Пройти маршрут'},
            {'id': 'save_draft', 'label': 'Сохранить маршрут в черновик'},
            {'id': 'refine', 'label': 'Указать агенту на ошибку'},
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
    final session = RoutePlanningSession(
      sessionId: 'mock-session-$_mockSessionSeq',
      status: 'active',
      constraints: params,
      confirmedFields: confirmedFields,
      aiPlanningEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockSessions[session.sessionId] = session;
    _mockMessages[session.sessionId] = [];
    return session;
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
    Object? controlValue,
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
      return _recordExchange(
        sessionId,
        text,
        RoutePlanningMessageResult(
          messageId: 'mock-msg-gen',
          sessionId: sessionId,
          role: 'assistant',
          text: generated.proposal.assistantText,
          intent: 'generate',
          proposal: generated.proposal,
          blocks: generated.proposal.blocks,
          provider: 'deterministic_generate',
        ),
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
    return _recordExchange(
      sessionId,
      text,
      RoutePlanningMessageResult(
        messageId: 'mock-msg-${_mockMessages[sessionId]?.length ?? 0}',
        sessionId: sessionId,
        role: 'assistant',
        text: reply,
        intent: 'on_topic_travel',
        askField: askField,
        blocks: [ActionsBlock(actions: actions)],
        provider: 'mock',
        fallback: true,
      ),
    );
  }

  /// Appends the user turn + agent reply to the in-memory transcript so
  /// [listMessages] (chat history resume) sees the same conversation the
  /// live UI just had, and bumps the session's `updatedAt` for sorting.
  RoutePlanningMessageResult _recordExchange(
    String sessionId,
    String userText,
    RoutePlanningMessageResult agentReply,
  ) {
    final transcript = _mockMessages.putIfAbsent(sessionId, () => []);
    transcript
      ..add(
        RoutePlanningMessageResult(
          messageId: 'mock-user-${transcript.length}',
          sessionId: sessionId,
          role: 'user',
          text: userText,
          blocks: const [],
        ),
      )
      ..add(agentReply);
    final session = _mockSessions[sessionId];
    if (session != null) {
      _mockSessions[sessionId] = RoutePlanningSession(
        sessionId: session.sessionId,
        status: session.status,
        constraints: session.constraints,
        aiPlanningEnabled: session.aiPlanningEnabled,
        confirmedFields: session.confirmedFields,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return agentReply;
  }

  @override
  Future<RoutePlanningSessionListResult> listSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final sorted = _mockSessions.values.toList()
      ..sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bTime = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
    final page = sorted.skip(offset).take(limit).toList(growable: false);
    return RoutePlanningSessionListResult(
      items: page,
      total: sorted.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<RoutePlanningMessageListResult> listMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final all = _mockMessages[sessionId] ?? const [];
    final page = all.skip(offset).take(limit).toList(growable: false);
    return RoutePlanningMessageListResult(
      items: page,
      total: all.length,
      limit: limit,
      offset: offset,
    );
  }
}
