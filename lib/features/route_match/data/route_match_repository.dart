import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/network/api_guard.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
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
}

/// Local fallback when DATA_SOURCE=mock (no backend).
class MockRouteMatchRepository implements RouteMatchRepository {
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
}
