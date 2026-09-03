import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_topic.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

const kRouteMatchStarterGreeting =
    'Здравствуй Путник! Выбери из предложенного или опиши свой идеальный маршрут.';

const kRouteMatchStarterActions = <Map<String, String>>[
  {'id': 'pace_calm', 'label': 'Спокойный маршрут'},
  {'id': 'pace_active', 'label': 'Активный маршрут'},
  {'id': 'interest_mountains', 'label': 'Маршрут по горам'},
  {'id': 'interest_sea', 'label': 'Путешествие к морю'},
  {'id': 'interest_food', 'label': 'Гастрономический тур'},
];

String defaultRouteMatchClockLabel() {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

List<RouteChatMessage> routeMatchStarterMessages({String time = '17:53'}) {
  return [
    RouteChatMessage(
      fromAgent: true,
      text: kRouteMatchStarterGreeting,
      time: time,
      actions: kRouteMatchStarterActions,
      actionsLayout: ChatActionsLayout.stack,
    ),
  ];
}

class RouteMatchChatState {
  const RouteMatchChatState({
    this.sessionId,
    this.constraints,
    this.messages = const [],
    this.sessionStarting = false,
    this.matching = false,
    this.sending = false,
    this.typing = false,
    this.lastFailure,
  });

  final String? sessionId;
  final RouteMatchParams? constraints;
  final List<RouteChatMessage> messages;
  final bool sessionStarting;
  final bool matching;
  final bool sending;
  final bool typing;
  final AppFailure? lastFailure;

  bool get busy => sending || typing || sessionStarting;

  RouteMatchChatState copyWith({
    String? sessionId,
    RouteMatchParams? constraints,
    List<RouteChatMessage>? messages,
    bool? sessionStarting,
    bool? matching,
    bool? sending,
    bool? typing,
    AppFailure? lastFailure,
    bool clearSession = false,
    bool clearConstraints = false,
    bool clearFailure = false,
  }) {
    return RouteMatchChatState(
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      constraints: clearConstraints ? null : (constraints ?? this.constraints),
      messages: messages ?? this.messages,
      sessionStarting: sessionStarting ?? this.sessionStarting,
      matching: matching ?? this.matching,
      sending: sending ?? this.sending,
      typing: typing ?? this.typing,
      lastFailure: clearFailure ? null : (lastFailure ?? this.lastFailure),
    );
  }
}

class RouteMatchNotifier extends StateNotifier<RouteMatchChatState> {
  RouteMatchNotifier({
    required this._repository,
    String Function()? clockLabel,
    this._cannedIntentDelay = const Duration(milliseconds: 350),
  }) : _clockLabel = clockLabel ?? defaultRouteMatchClockLabel,
       super(RouteMatchChatState(messages: routeMatchStarterMessages()));

  final RouteMatchRepository _repository;
  final String Function() _clockLabel;
  final Duration _cannedIntentDelay;
  Future<void>? _sessionInFlight;

  void clearFailure() {
    if (state.lastFailure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  Future<void> ensureSession(RouteMatchParams draft) async {
    final inFlight = _sessionInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    if (state.sessionId != null) {
      return;
    }
    final future = _createSession(draft);
    _sessionInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_sessionInFlight, future)) {
        _sessionInFlight = null;
      }
    }
  }

  Future<void> _createSession(RouteMatchParams draft) async {
    if (state.sessionId != null || state.sessionStarting) {
      return;
    }
    state = state.copyWith(sessionStarting: true, clearFailure: true);
    try {
      final session = await _repository.createSession(
        draft,
        confirmedFields: const [],
      );
      state = state.copyWith(
        sessionId: session.sessionId,
        constraints: session.constraints,
        sessionStarting: false,
      );
    } on AppFailure catch (error) {
      state = state.copyWith(sessionStarting: false, lastFailure: error);
    }
  }

  Future<void> startNewChat(RouteMatchParams draft) async {
    if (state.busy) {
      return;
    }
    final previousId = state.sessionId;
    state = state.copyWith(
      sessionStarting: true,
      messages: const [],
      clearSession: true,
      clearConstraints: true,
      clearFailure: true,
    );
    if (previousId != null) {
      try {
        await _repository.closeSession(previousId);
      } on AppFailure {
        // Best-effort close; still create a fresh session below.
      }
    }
    try {
      final session = await _repository.createSession(
        draft,
        confirmedFields: const [],
      );
      state = state.copyWith(
        sessionId: session.sessionId,
        constraints: session.constraints,
        sessionStarting: false,
        messages: routeMatchStarterMessages(time: _clockLabel()),
      );
    } on AppFailure catch (error) {
      state = state.copyWith(sessionStarting: false, lastFailure: error);
    }
  }

  /// Reopens an existing planning session from the chat history screen and
  /// replays its stored transcript.
  ///
  /// Stored rows parse through the same [RoutePlanningMessageResult] shape as
  /// live replies, so history reuses [_agentMessageFromResult] rather than a
  /// second mapping. Timestamps come from the row when present — a replayed
  /// turn must not be stamped with the current clock.
  Future<void> resumeSession(RoutePlanningSession session) async {
    state = state.copyWith(
      sessionId: session.sessionId,
      constraints: session.constraints,
      messages: const [],
      sessionStarting: true,
      clearFailure: true,
    );
    try {
      final page = await _repository.listMessages(session.sessionId);
      state = state.copyWith(
        sessionStarting: false,
        messages: [
          for (final item in page.items)
            if (item.role == 'user')
              RouteChatMessage(
                fromAgent: false,
                text: item.text,
                time: _storedTimeLabel(item.createdAt),
              )
            else
              _agentMessageFromResult(item),
        ],
      );
    } on AppFailure catch (error) {
      state = state.copyWith(sessionStarting: false, lastFailure: error);
    }
  }

  String _storedTimeLabel(DateTime? createdAt) {
    final local = createdAt?.toLocal();
    if (local == null) {
      return _clockLabel();
    }
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<RouteMatchResult?> match(RouteMatchParams params) async {
    if (state.matching) {
      return null;
    }
    state = state.copyWith(matching: true, clearFailure: true);
    try {
      final result = await _repository.match(params);
      state = state.copyWith(matching: false);
      return result;
    } on AppFailure catch (error) {
      state = state.copyWith(matching: false, lastFailure: error);
      return null;
    }
  }

  Future<RouteProposalResult?> acceptProposal(String id) async {
    try {
      return await _repository.acceptProposal(id);
    } on AppFailure catch (error) {
      state = state.copyWith(lastFailure: error);
      return null;
    }
  }

  Future<void> rejectProposal(String proposalId) async {
    try {
      await _repository.rejectProposal(proposalId);
      state = state.copyWith(
        messages: [
          ...state.messages,
          RouteChatMessage(
            fromAgent: true,
            text: 'Хорошо, соберём маршрут заново. Что изменить?',
            time: _clockLabel(),
            actions: const [
              {'id': 'want_generate', 'label': 'Подбери маршрут'},
              {'id': 'pace_calm', 'label': 'Спокойный маршрут'},
              {'id': 'pace_active', 'label': 'Активный маршрут'},
            ],
          ),
        ],
      );
    } on AppFailure catch (error) {
      state = state.copyWith(lastFailure: error);
    }
  }

  void refineProposal() {
    state = state.copyWith(
      messages: [
        ...state.messages,
        RouteChatMessage(
          fromAgent: true,
          text: 'Что хотите изменить — город, темп, интересы или длительность?',
          time: _clockLabel(),
          actions: const [
            {'id': 'want_generate', 'label': 'Подбери маршрут'},
            {'id': 'pace_calm', 'label': 'Хочу спокойно'},
            {'id': 'pace_active', 'label': 'Хочу активно'},
            {'id': 'interest_sea', 'label': 'Больше моря'},
            {'id': 'interest_mountains', 'label': 'Больше гор'},
            {'id': 'duration_d3_5', 'label': '3–5 дней'},
          ],
        ),
      ],
    );
  }

  Future<void> onChatAction(String id, String label) async {
    if (id == 'want_generate') {
      await sendMessage(
        text: 'подбери маршрут',
        wantGenerate: true,
        actionId: id,
      );
      return;
    }
    await sendMessage(text: label, actionId: id);
  }

  Future<void> confirmControls(Map<String, Object> values) async {
    if (state.busy || values.isEmpty) {
      return;
    }
    final entries = values.entries.toList(growable: false);
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      await sendMessage(
        text: _controlLabel(entry.key, entry.value),
        actionId: entry.key,
        controlValue: entry.value,
        silent: true,
        appendReply: i == entries.length - 1,
      );
    }
  }

  Future<void> sendMessage({
    required String text,
    bool wantGenerate = false,
    String? actionId,
    Object? controlValue,
    bool silent = false,
    bool appendReply = true,
    RouteMatchParams? draftForSession,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending || state.typing) {
      return;
    }
    var messages = state.messages;
    if (!silent) {
      messages = [
        ...messages,
        RouteChatMessage(fromAgent: false, text: trimmed, time: _clockLabel()),
      ];
    }
    state = state.copyWith(
      sending: true,
      messages: messages,
      clearFailure: true,
    );

    final intent = classifyRouteMatchChatIntent(trimmed);
    final useLocalCanned =
        intent == RouteMatchChatIntent.crisis ||
        intent == RouteMatchChatIntent.offTopic ||
        intent == RouteMatchChatIntent.injectionAttempt;
    if (useLocalCanned) {
      if (_cannedIntentDelay > Duration.zero) {
        await Future<void>.delayed(_cannedIntentDelay);
      }
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        sending: false,
        messages: appendReply
            ? [
                ...state.messages,
                RouteChatMessage(
                  fromAgent: true,
                  text: cannedReplyForIntent(intent),
                  time: _clockLabel(),
                  isCrisis: intent == RouteMatchChatIntent.crisis,
                  actions: intent == RouteMatchChatIntent.offTopic
                      ? const [
                          {'id': 'want_generate', 'label': 'Подбери маршрут'},
                          {'id': 'pace_calm', 'label': 'Хочу спокойно'},
                          {'id': 'interest_sea', 'label': 'Больше моря'},
                        ]
                      : const [],
                ),
              ]
            : state.messages,
      );
      return;
    }

    state = state.copyWith(typing: true);
    try {
      if (state.sessionId == null) {
        await ensureSession(
          draftForSession ??
              const RouteMatchParams(
                city: 'Крым',
                duration: RouteDurationOption.d3_5,
                people: 2,
                interests: ['Природа'],
                pace: RoutePace.calm,
              ),
        );
      }
      final sessionId = state.sessionId;
      if (sessionId == null) {
        if (!mounted) {
          return;
        }
        state = state.copyWith(typing: false, sending: false);
        return;
      }
      final result = await _repository.postMessage(
        sessionId: sessionId,
        text: trimmed,
        wantGenerate: wantGenerate,
        actionId: actionId,
        controlValue: controlValue,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        typing: false,
        sending: false,
        constraints: actionId == null
            ? state.constraints
            : _patchedConstraints(state.constraints, actionId),
        messages: appendReply
            ? [...state.messages, _agentMessageFromResult(result)]
            : state.messages,
      );
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(typing: false, sending: false, lastFailure: error);
    }
  }

  RouteMatchParams? _patchedConstraints(
    RouteMatchParams? current,
    String actionId,
  ) {
    if (current == null) {
      return current;
    }
    return applyRouteMatchConstraintPatch(current, actionId);
  }

  RouteChatMessage _agentMessageFromResult(RoutePlanningMessageResult result) {
    if (result.proposal != null) {
      return _agentProposalMessage(result.proposal!);
    }
    return RouteChatMessage(
      fromAgent: true,
      text: result.text,
      time: _clockLabel(),
      isCrisis: result.intent == 'crisis',
      placeChips: placeChipsFromBlocks(result.blocks),
      catalogMatch: catalogMatchFromBlocks(result.blocks),
      actions: actionsFromBlocks(result.blocks),
      actionsLayout: actionsLayoutFromBlocks(result.blocks),
      actionsSheetTitle: actionsSheetTitleFromBlocks(result.blocks),
      recommendations: recommendationsFromBlocks(result.blocks),
      sliders: slidersFromBlocks(result.blocks),
      toggles: togglesFromBlocks(result.blocks),
      selects: selectsFromBlocks(result.blocks),
    );
  }

  RouteChatMessage _agentProposalMessage(RouteProposal proposal) {
    final card = proposal.cardData;
    return RouteChatMessage(
      fromAgent: true,
      text: proposal.assistantText,
      time: _clockLabel(),
      proposalId: card.proposalId,
      proposalTitle: card.title,
      proposalStopsCount: card.stopsCount,
      proposalDurationMinutes: card.durationMinutes,
      proposalCoverUrl: card.coverUrl,
      proposalCard: card,
      placeChips: placeChipsFromBlocks(proposal.blocks),
      catalogMatch: catalogMatchFromBlocks(proposal.blocks),
      actions: const [],
      actionsLayout: actionsLayoutFromBlocks(proposal.blocks),
    );
  }
}

final routeMatchNotifierProvider =
    StateNotifierProvider.autoDispose<RouteMatchNotifier, RouteMatchChatState>((
      ref,
    ) {
      return RouteMatchNotifier(
        repository: ref.watch(routeMatchRepositoryProvider),
      );
    });

String _controlLabel(String id, Object value) => switch (id) {
  'budget_amount' => 'Бюджет ${value is num ? value.round() : value} ₽',
  'with_children' => value == true ? 'С детьми' : 'Без детей',
  'with_pets' => value == true ? 'С питомцами' : 'Без питомцев',
  // У селекта значение уже человекочитаемое («Ялта»), его и отправляем.
  // Раньше сюда падал `_ => id`, и в чат уходило слово «city» — модель
  // видела его вместо названия города.
  _ when value is String && value.isNotEmpty => value,
  _ => id,
};

RouteMatchParams applyRouteMatchConstraintPatch(
  RouteMatchParams current,
  String actionId,
) {
  List<String> mergeInterest(String extra) {
    final out = [...current.interests];
    if (!out.any((item) => item.toLowerCase() == extra.toLowerCase())) {
      out.add(extra);
    }
    return out;
  }

  return switch (actionId) {
    'pace_calm' => current.copyWith(pace: RoutePace.calm),
    'pace_moderate' => current.copyWith(pace: RoutePace.moderate),
    'pace_active' => current.copyWith(pace: RoutePace.active),
    'interest_sea' => current.copyWith(interests: mergeInterest('море')),
    'interest_mountains' => current.copyWith(interests: mergeInterest('горы')),
    'interest_food' => current.copyWith(interests: mergeInterest('еда')),
    'interest_romance' => current.copyWith(
      interests: mergeInterest('романтика'),
    ),
    'with_children' => current.copyWith(withChildren: true),
    'transport_car' => current.copyWith(transportMode: 'car'),
    'transport_public' => current.copyWith(transportMode: 'public'),
    'transport_walk' => current.copyWith(transportMode: 'walk'),
    'transport_mixed' => current.copyWith(transportMode: 'mixed'),
    'duration_d1_2' => current.copyWith(duration: RouteDurationOption.d1_2),
    'duration_d3_5' => current.copyWith(duration: RouteDurationOption.d3_5),
    'duration_d6_7' => current.copyWith(duration: RouteDurationOption.d6_7),
    'duration_d7plus' => current.copyWith(duration: RouteDurationOption.d7plus),
    'people_1' => current.copyWith(people: 1),
    'people_2' => current.copyWith(people: 2),
    'people_3_plus' => current.copyWith(people: 3),
    _ => current,
  };
}

List<RouteChatPlaceChipData> placeChipsFromBlocks(List<RouteChatBlock> blocks) {
  return [
    for (final block in blocks)
      if (block is PlaceChipBlock)
        RouteChatPlaceChipData(
          placeId: block.placeId,
          title: block.title,
          subtitle: block.subtitle,
          imageUrl: block.imageUrl,
          durationMinutes: block.durationMinutes,
        ),
  ];
}

List<CatalogRouteItem> catalogMatchFromBlocks(List<RouteChatBlock> blocks) {
  for (final block in blocks) {
    if (block is CatalogMatchBlock) {
      return block.routes;
    }
  }
  return const [];
}

ChatActionsLayout actionsLayoutFromBlocks(List<RouteChatBlock> blocks) {
  for (final block in blocks) {
    if (block is ActionsBlock) {
      return block.layout;
    }
  }
  return ChatActionsLayout.wrap;
}

String? actionsSheetTitleFromBlocks(List<RouteChatBlock> blocks) {
  for (final block in blocks) {
    if (block is ActionsBlock) {
      return block.sheetTitle;
    }
  }
  return null;
}

List<Map<String, String>> actionsFromBlocks(List<RouteChatBlock> blocks) {
  return [
    for (final block in blocks)
      if (block is ActionsBlock)
        for (final action in block.actions)
          if ((action['id'] ?? '').isNotEmpty &&
              (action['label'] ?? '').isNotEmpty)
            {'id': action['id']!, 'label': action['label']!},
  ];
}

List<RouteChatRecommendationData> recommendationsFromBlocks(
  List<RouteChatBlock> blocks,
) {
  return [
    for (final block in blocks)
      if (block is RecommendationCardBlock)
        RouteChatRecommendationData(
          id: block.id,
          title: block.title,
          body: block.body,
          acceptActionId: block.acceptActionId,
          acceptLabel: block.acceptLabel,
        ),
  ];
}

List<RouteChatSliderData> slidersFromBlocks(List<RouteChatBlock> blocks) {
  return [
    for (final block in blocks)
      if (block is SliderBlock)
        RouteChatSliderData(
          id: block.id,
          label: block.label,
          minValue: block.minValue,
          maxValue: block.maxValue,
          step: block.step,
          value: block.value,
          unit: block.unit,
        ),
  ];
}

List<RouteChatSelectData> selectsFromBlocks(List<RouteChatBlock> blocks) {
  return [
    for (final block in blocks)
      if (block is SelectBlock && block.options.isNotEmpty)
        RouteChatSelectData(
          id: block.id,
          label: block.label,
          options: block.options,
          value: block.value,
          placeholder: block.placeholder,
        ),
  ];
}

List<RouteChatToggleData> togglesFromBlocks(List<RouteChatBlock> blocks) {
  return [
    for (final block in blocks)
      if (block is ToggleBlock)
        RouteChatToggleData(
          id: block.id,
          label: block.label,
          value: block.value,
        ),
  ];
}
