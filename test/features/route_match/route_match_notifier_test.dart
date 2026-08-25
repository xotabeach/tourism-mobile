import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_notifier.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

class FakeRouteMatchRepository implements RouteMatchRepository {
  var createSessionCalls = 0;
  var postMessageCalls = 0;
  final acceptCalls = <String>[];
  final rejectCalls = <String>[];
  var sessionSeq = 0;
  RoutePlanningMessageResult? nextMessage;
  RouteProposal? acceptResult;
  AppFailure? createError;
  AppFailure? postError;
  List<RoutePlanningMessageResult> storedMessages = const [];
  AppFailure? listMessagesError;

  @override
  Future<RoutePlanningSessionListResult> listSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    return const RoutePlanningSessionListResult(
      items: [],
      total: 0,
      limit: 20,
      offset: 0,
    );
  }

  @override
  Future<RoutePlanningMessageListResult> listMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (listMessagesError != null) {
      throw listMessagesError!;
    }
    return RoutePlanningMessageListResult(
      items: storedMessages,
      total: storedMessages.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<RoutePlanningSession> createSession(
    RouteMatchParams params, {
    List<String> confirmedFields = const [],
  }) async {
    createSessionCalls += 1;
    if (createError != null) {
      throw createError!;
    }
    sessionSeq += 1;
    return RoutePlanningSession(
      sessionId: 'sess-$sessionSeq',
      status: 'active',
      constraints: params,
      aiPlanningEnabled: true,
    );
  }

  @override
  Future<RoutePlanningSession> closeSession(String sessionId) async {
    return RoutePlanningSession(
      sessionId: sessionId,
      status: 'closed',
      constraints: const RouteMatchParams(
        city: 'Крым',
        duration: RouteDurationOption.d3_5,
        people: 2,
        interests: ['Природа'],
        pace: RoutePace.calm,
      ),
      aiPlanningEnabled: true,
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
    postMessageCalls += 1;
    if (postError != null) {
      throw postError!;
    }
    return nextMessage ??
        RoutePlanningMessageResult(
          messageId: 'msg-$postMessageCalls',
          sessionId: sessionId,
          role: 'assistant',
          text: 'Понял: $text',
          blocks: const [],
        );
  }

  @override
  Future<RouteProposalResult> acceptProposal(String id) async {
    acceptCalls.add(id);
    return acceptResult ??
        RouteProposal(
          proposalId: id,
          status: 'accepted',
          channel: 'chat',
          title: 'Ялта',
          assistantText: 'Маршрут создан.',
          placeIds: const ['p1'],
          durationMinutes: 180,
          routeId: 'route-accepted',
          blocks: const [],
          quota: const RouteQuotaSnapshot(dailyUsed: 1, weeklyUsed: 1),
        );
  }

  @override
  Future<RouteProposalResult> rejectProposal(String id) async {
    rejectCalls.add(id);
    return RouteProposal(
      proposalId: id,
      status: 'rejected',
      channel: 'chat',
      title: 'Ялта',
      assistantText: 'Отклонено.',
      placeIds: const ['p1'],
      durationMinutes: 180,
      blocks: const [],
      quota: const RouteQuotaSnapshot(dailyUsed: 1, weeklyUsed: 1),
    );
  }

  @override
  Future<RouteMatchResult> match(RouteMatchParams params) {
    throw UnimplementedError();
  }

  @override
  Future<RouteGenerateResult> generate({
    required String channel,
    required RouteMatchParams params,
  }) {
    throw UnimplementedError();
  }
}

const _draft = RouteMatchParams(
  city: 'Ялта',
  duration: RouteDurationOption.d3_5,
  people: 2,
  interests: ['Природа'],
  pace: RoutePace.moderate,
);

RouteMatchNotifier _notifier(FakeRouteMatchRepository repo) {
  return RouteMatchNotifier(
    repository: repo,
    clockLabel: () => '12:00',
    cannedIntentDelay: Duration.zero,
  );
}

void main() {
  test('ensureSession calls createSession once across sends', () async {
    final repo = FakeRouteMatchRepository();
    final chat = _notifier(repo);

    await chat.ensureSession(_draft);
    await chat.sendMessage(text: 'хочу Ялту', draftForSession: _draft);
    await chat.sendMessage(text: 'на три дня', draftForSession: _draft);

    expect(repo.createSessionCalls, 1);
    expect(repo.postMessageCalls, 2);
    expect(chat.state.sessionId, 'sess-1');
  });

  test(
    'sendMessage appends user and assistant bubbles from postMessage',
    () async {
      final repo = FakeRouteMatchRepository()
        ..nextMessage = const RoutePlanningMessageResult(
          messageId: 'm1',
          sessionId: 'sess-1',
          role: 'assistant',
          text: 'Отличный выбор, Ялта.',
          blocks: [],
        );
      final chat = _notifier(repo);

      await chat.sendMessage(text: 'хочу Ялту', draftForSession: _draft);

      expect(repo.postMessageCalls, 1);
      expect(
        chat.state.messages.where((m) => !m.fromAgent).map((m) => m.text),
        ['хочу Ялту'],
      );
      expect(chat.state.messages.last.fromAgent, isTrue);
      expect(chat.state.messages.last.text, 'Отличный выбор, Ялта.');
    },
  );

  test(
    'acceptProposal hits repo and returns routeId; reject does not accept',
    () async {
      final repo = FakeRouteMatchRepository();
      final chat = _notifier(repo);
      await chat.ensureSession(_draft);

      final accepted = await chat.acceptProposal('prop-1');
      expect(repo.acceptCalls, ['prop-1']);
      expect(accepted?.routeId, 'route-accepted');

      await chat.rejectProposal('prop-1');
      expect(repo.rejectCalls, ['prop-1']);
      expect(repo.acceptCalls, ['prop-1']);
      expect(chat.state.messages.last.text, contains('соберём маршрут заново'));
    },
  );

  test(
    'constraint chip patches session constraints after postMessage',
    () async {
      final repo = FakeRouteMatchRepository();
      final chat = _notifier(repo);
      await chat.ensureSession(_draft);
      await chat.sendMessage(
        text: 'Активный маршрут',
        actionId: 'pace_active',
        draftForSession: _draft,
      );
      expect(chat.state.constraints?.pace, RoutePace.active);
    },
  );

  test(
    'resumeSession replays the stored transcript instead of the starter',
    () async {
      final repo = FakeRouteMatchRepository()
        ..storedMessages = [
          RoutePlanningMessageResult(
            messageId: 'm1',
            sessionId: 'sess-history',
            role: 'user',
            text: 'Подбери спокойный маршрут по Ялте',
            blocks: const [],
            createdAt: DateTime.utc(2026, 8, 25, 9, 30),
          ),
          const RoutePlanningMessageResult(
            messageId: 'm2',
            sessionId: 'sess-history',
            role: 'assistant',
            text: 'Собрал черновик маршрута из Ялты.',
            blocks: [],
          ),
        ];
      final chat = _notifier(repo);

      await chat.resumeSession(
        const RoutePlanningSession(
          sessionId: 'sess-history',
          status: 'closed',
          constraints: _draft,
          aiPlanningEnabled: true,
        ),
      );

      expect(chat.state.sessionId, 'sess-history');
      expect(chat.state.messages, hasLength(2));
      expect(chat.state.messages.first.fromAgent, isFalse);
      expect(
        chat.state.messages.first.text,
        'Подбери спокойный маршрут по Ялте',
      );
      // Stored rows keep their own timestamp; only rows without one fall back
      // to the clock.
      expect(chat.state.messages.first.time, isNot('12:00'));
      expect(chat.state.messages.last.time, '12:00');
      expect(chat.state.sessionStarting, isFalse);
    },
  );

  test('resumeSession surfaces a failure instead of hanging', () async {
    final repo = FakeRouteMatchRepository()
      ..listMessagesError = const NetworkFailure('no network');
    final chat = _notifier(repo);

    await chat.resumeSession(
      const RoutePlanningSession(
        sessionId: 'sess-history',
        status: 'closed',
        constraints: _draft,
        aiPlanningEnabled: true,
      ),
    );

    expect(chat.state.sessionStarting, isFalse);
    expect(chat.state.lastFailure?.message, 'no network');
  });
}
