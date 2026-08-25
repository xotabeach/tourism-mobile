import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_mode_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_topic.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Подбор маршрута — форма по параметрам + чат «Подбор с ИИ».
///
/// [pixelReference] loads golden/demo chat content only for visual tests.
class RouteMatchScreen extends ConsumerStatefulWidget {
  const RouteMatchScreen({
    super.key,
    this.pixelReference = false,
    this.initialMode = RouteMatchMode.params,
    this.resumeSession,
  });

  static const routePath = '/match';

  /// Separates golden/demo fixtures from production chat logic.
  final bool pixelReference;

  final RouteMatchMode initialMode;

  /// Set from [ChatHistoryScreen]: opens straight into chat mode on this
  /// existing session and replays its transcript instead of the params form.
  final RoutePlanningSession? resumeSession;

  @override
  ConsumerState<RouteMatchScreen> createState() => _RouteMatchScreenState();
}

class _RouteMatchScreenState extends ConsumerState<RouteMatchScreen>
    with WidgetsBindingObserver {
  late RouteMatchMode _mode;
  String? _city;
  RouteTripType? _tripType = RouteTripType.romance;
  RouteDurationOption _duration = RouteDurationOption.d3_5;
  int _people = 2;
  final Set<String> _interests = {'Природа'};
  RoutePace _pace = RoutePace.calm;
  String? _season;
  RouteTransportMode? _transportMode;
  RouteDayKind _dayKind = RouteDayKind.any;
  bool _withChildren = false;
  bool _withPets = false;
  bool _avoidCrowds = false;

  final _cityController = TextEditingController();
  final _budgetController = TextEditingController();
  final _cityFocus = FocusNode(debugLabel: 'route-match-city');
  final _aiController = TextEditingController();
  final _aiFocus = FocusNode(debugLabel: 'route-match-ai');
  final _paramsScroll = ScrollController();
  final _aiScroll = ScrollController();
  final _modeSwitcherKey = GlobalKey();

  bool _cityError = false;
  bool _matching = false;
  bool _typing = false;
  bool _sending = false;
  bool _composerDirty = false;
  double _appBarProgress = 0;
  double _lastViewInset = 0;
  String? _chatSessionId;
  bool _sessionStarting = false;
  RouteMatchParams? _sessionConstraints;

  static const _starterChatActions = <Map<String, String>>[
    {'id': 'pace_calm', 'label': 'Спокойный маршрут'},
    {'id': 'pace_active', 'label': 'Активный маршрут'},
    {'id': 'interest_mountains', 'label': 'Маршрут по горам'},
    {'id': 'interest_sea', 'label': 'Путешествие к морю'},
    {'id': 'interest_food', 'label': 'Гастрономический тур'},
  ];

  static const _starterGreeting =
      'Здравствуй Путник! Выбери из предложенного или опиши свой идеальный маршрут.';

  late List<RouteChatMessage> _messages;

  static const _popularCities = ['Симферополь', 'Ялта', 'Алушта', 'Саки'];
  static const _allCities = [
    'Симферополь',
    'Ялта',
    'Алушта',
    'Саки',
    'Севастополь',
    'Евпатория',
    'Феодосия',
    'Керчь',
    'Бахчисарай',
    'Судак',
  ];
  static const _interestOptions = [
    'Природа',
    'Пляж',
    'Горы',
    'Еда',
    'История',
    'Экстрим',
    'Фото',
    'Леса',
    'Спорт',
    'Лошади',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _aiFocus.addListener(_onAiFocusChanged);
    _paramsScroll.addListener(_syncAppBarFromActiveScroll);
    _aiScroll.addListener(_syncAppBarFromActiveScroll);
    final resume = widget.resumeSession;
    _mode = resume != null ? RouteMatchMode.ai : widget.initialMode;
    if (resume != null) {
      _chatSessionId = resume.sessionId;
      _sessionConstraints = resume.constraints;
    }
    _messages = widget.pixelReference
        ? [
            const RouteChatMessage(
              fromAgent: true,
              text: RouteBuilderDemoState.pixelAgentGreeting,
              time: '17:53',
            ),
            const RouteChatMessage(
              fromAgent: false,
              text: RouteBuilderDemoState.pixelUserMessage,
              time: '17:52',
            ),
            const RouteChatMessage(
              fromAgent: true,
              text: RouteBuilderDemoState.pixelAgentShort,
              time: '17:53',
            ),
          ]
        : resume != null
        ? const []
        : [
            const RouteChatMessage(
              fromAgent: true,
              text: _starterGreeting,
              time: '17:53',
              actions: _starterChatActions,
              actionsLayout: ChatActionsLayout.stack,
            ),
          ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAiModeProvider();
      if (widget.pixelReference && _mode == RouteMatchMode.ai) {
        _scrollAiToDemoOffset();
      }
      if (resume != null) {
        unawaited(_loadResumeHistory(resume.sessionId));
      }
    });
  }

  Future<void> _loadResumeHistory(String sessionId) async {
    if (!ref.read(sessionProvider).travelPlusActive) {
      unawaited(context.push('/profile/settings/travel-plus'));
      return;
    }
    setState(() => _sessionStarting = true);
    try {
      final page = await ref
          .read(routeMatchRepositoryProvider)
          .listMessages(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          for (final item in page.items)
            item.role == 'user'
                ? RouteChatMessage(
                    fromAgent: false,
                    text: item.text,
                    time: _timeLabel(item.createdAt),
                  )
                : _agentMessageFromResult(item),
        ];
        _sessionStarting = false;
      });
      _scrollAiToEnd(animate: false);
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sessionStarting = false);
      _showChatFailure(error);
    }
  }

  String _timeLabel(DateTime? createdAt) {
    final local = createdAt?.toLocal();
    if (local == null) {
      return _nowTime();
    }
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void deactivate() {
    if (ref.read(routeMatchAiModeProvider)) {
      // deactivate() can run mid widget-tree-finalization (popping a
      // pushed instance, e.g. a resumed session leaving the AI mode flag
      // set) — Riverpod forbids writing a provider from inside that pass.
      // Capture the notifier now (still valid) and write on a microtask.
      final notifier = ref.read(routeMatchAiModeProvider.notifier);
      scheduleMicrotask(() {
        if (notifier.mounted) {
          notifier.state = false;
        }
      });
    }
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cityController.dispose();
    _budgetController.dispose();
    _cityFocus.dispose();
    _aiController.dispose();
    _aiFocus
      ..removeListener(_onAiFocusChanged)
      ..dispose();
    _paramsScroll
      ..removeListener(_syncAppBarFromActiveScroll)
      ..dispose();
    _aiScroll
      ..removeListener(_syncAppBarFromActiveScroll)
      ..dispose();
    super.dispose();
  }

  void _onAiFocusChanged() {
    if (!_aiFocus.hasFocus) return;
    _scrollAiToEnd();
    _scrollAiToEndDuringKeyboardAnimation();
  }

  double _keyboardInset() {
    return MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
  }

  @override
  void didChangeMetrics() {
    if (!mounted || _mode != RouteMatchMode.ai) return;
    final inset = _keyboardInset();
    final opened = inset > _lastViewInset + 1;
    _lastViewInset = inset;
    if (opened || (inset > 0 && _aiFocus.hasFocus)) {
      _scrollAiToEnd();
      if (opened) _scrollAiToEndDuringKeyboardAnimation();
    }
  }

  void _scrollAiToEndDuringKeyboardAnimation() {
    for (final delay in const [
      Duration(milliseconds: 50),
      Duration(milliseconds: 160),
      Duration(milliseconds: 320),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !_aiFocus.hasFocus) return;
        _scrollAiToEnd(animate: false);
      });
    }
  }

  void _syncAiModeProvider() {
    final hideNav = _mode == RouteMatchMode.ai;
    if (ref.read(routeMatchAiModeProvider) != hideNav) {
      ref.read(routeMatchAiModeProvider.notifier).state = hideNav;
    }
  }

  void _setMode(RouteMatchMode mode) {
    if (mode == RouteMatchMode.ai &&
        !widget.pixelReference &&
        !ref.read(sessionProvider).travelPlusActive) {
      unawaited(context.push('/profile/settings/travel-plus'));
      return;
    }
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    _syncAiModeProvider();
    if (mode == RouteMatchMode.ai &&
        !widget.pixelReference &&
        _chatSessionId == null) {
      unawaited(_ensureChatSession());
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncAppBarFromActiveScroll(),
    );
  }

  Future<void> _ensureChatSession() async {
    if (widget.pixelReference || _chatSessionId != null || _sessionStarting) {
      return;
    }
    setState(() => _sessionStarting = true);
    try {
      final seeded = _seedChatSessionParams();
      final session = await ref
          .read(routeMatchRepositoryProvider)
          .createSession(
            seeded.params,
            confirmedFields: seeded.confirmedFields,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _chatSessionId = session.sessionId;
        _sessionConstraints = session.constraints;
        _sessionStarting = false;
      });
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sessionStarting = false);
      _showChatFailure(error);
    }
  }

  ({RouteMatchParams params, List<String> confirmedFields})
  _seedChatSessionParams() {
    final city = _city?.trim();
    final hasCity = city != null && city.isNotEmpty;
    final params = _buildMatchParams(city: hasCity ? city : 'Крым');
    // Form values are a draft for generate only. Nothing is "stated in chat"
    // until the user taps a chip / control or writes it in this session.
    return (params: params, confirmedFields: const <String>[]);
  }

  Future<void> _startNewChat() async {
    if (widget.pixelReference || _sessionStarting || _sending || _typing) {
      return;
    }
    final previousId = _chatSessionId;
    setState(() {
      _sessionStarting = true;
      _messages = <RouteChatMessage>[];
      _chatSessionId = null;
      _sessionConstraints = null;
      _composerDirty = false;
      _aiController.clear();
    });
    final repo = ref.read(routeMatchRepositoryProvider);
    if (previousId != null) {
      try {
        await repo.closeSession(previousId);
      } on AppFailure {
        // Best-effort close; still create a fresh session below.
      }
    }
    try {
      final seeded = _seedChatSessionParams();
      final session = await repo.createSession(
        seeded.params,
        confirmedFields: seeded.confirmedFields,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _chatSessionId = session.sessionId;
        _sessionConstraints = session.constraints;
        _sessionStarting = false;
        _messages = [
          RouteChatMessage(
            fromAgent: true,
            text: _starterGreeting,
            time: _nowTime(),
            actions: _starterChatActions,
            actionsLayout: ChatActionsLayout.stack,
          ),
        ];
      });
      _scrollAiToEnd();
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sessionStarting = false);
      _showChatFailure(error);
    }
  }

  void _syncAppBarFromActiveScroll() {
    if (!mounted) {
      return;
    }
    final controller = _mode == RouteMatchMode.ai ? _aiScroll : _paramsScroll;
    final offset = controller.hasClients ? controller.offset : 0.0;
    final progress = ((offset - 20) / 64).clamp(0.0, 1.0);
    if ((progress - _appBarProgress).abs() < 0.001) {
      return;
    }
    setState(() => _appBarProgress = progress);
  }

  void _goBack() {
    // Two very different homes for this screen: the tab-root instance has
    // no Navigator route beneath it (go to the Home tab is the only
    // meaningful "back"), but resumeSession pushes it as a real page from
    // ChatHistoryScreen — there, back must pop to that page, not jump to
    // the Home tab and strand it.
    if (widget.resumeSession != null && context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  void _selectCity(String city) {
    setState(() {
      _city = city;
      _cityController.text = city;
      _cityError = false;
    });
    _cityFocus.unfocus();
  }

  void _onCityTextChanged(String value) {
    setState(() {
      _city = value.trim().isEmpty ? null : value.trim();
      _cityError = false;
    });
  }

  void _clearCity() {
    setState(() {
      _city = null;
      _cityController.clear();
      _cityError = false;
    });
  }

  List<String> get _filteredSuggestions {
    final q = _cityController.text.trim().toLowerCase();
    if (q.isEmpty || (_city != null && _city!.toLowerCase() == q)) {
      return const [];
    }
    return _allCities
        .where((c) => c.toLowerCase().contains(q) && c.toLowerCase() != q)
        .take(5)
        .toList();
  }

  Future<void> _onMatchPressed() async {
    if (_matching) {
      return;
    }
    final city = _city?.trim();
    if (city == null || city.isEmpty) {
      setState(() => _cityError = true);
      unawaited(
        _paramsScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
      return;
    }
    setState(() => _matching = true);
    try {
      final params = _buildMatchParams(city: city);
      final result = await ref.read(routeMatchRepositoryProvider).match(params);
      if (!mounted) {
        return;
      }
      ref.read(lastRouteMatchResultProvider.notifier).state = result;
      ref.read(lastRouteMatchParamsProvider.notifier).state = params;
      unawaited(context.pushNamed(AppRouteNames.routeMatchResults));
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _matching = false);
      }
    }
  }

  RouteMatchParams _buildMatchParams({required String city}) {
    final session = ref.read(sessionProvider);
    final advanced = session.advancedFiltersEnabled || session.travelPlusActive;
    final budgetRaw = _budgetController.text.trim();
    final budget = budgetRaw.isEmpty ? null : int.tryParse(budgetRaw);
    return RouteMatchParams(
      city: city,
      tripType: _tripType,
      duration: _duration,
      people: _people,
      interests: _interests.toList(growable: false),
      pace: _pace,
      season: _season,
      transportMode: _transportMode?.apiValue,
      dayKind: _dayKind == RouteDayKind.any ? null : _dayKind.apiValue,
      budgetAmount: advanced ? budget : null,
      withChildren: advanced && _withChildren ? true : null,
      withPets: advanced && _withPets ? true : null,
      avoidCrowds: advanced && _avoidCrowds ? true : null,
    );
  }

  RouteChatMessage _agentMessageFromResult(RoutePlanningMessageResult result) {
    if (result.proposal != null) {
      return _agentProposalMessage(result.proposal!);
    }
    return RouteChatMessage(
      fromAgent: true,
      text: result.text,
      time: _nowTime(),
      isCrisis: result.intent == 'crisis',
      placeChips: _placeChipsFromBlocks(result.blocks),
      catalogMatch: _catalogMatchFromBlocks(result.blocks),
      actions: _actionsFromBlocks(result.blocks),
      actionsLayout: _actionsLayoutFromBlocks(result.blocks),
      actionsSheetTitle: _actionsSheetTitleFromBlocks(result.blocks),
      recommendations: _recommendationsFromBlocks(result.blocks),
      sliders: _slidersFromBlocks(result.blocks),
      toggles: _togglesFromBlocks(result.blocks),
    );
  }

  RouteChatMessage _agentProposalMessage(RouteProposal proposal) {
    final card = proposal.cardData;
    return RouteChatMessage(
      fromAgent: true,
      text: proposal.assistantText,
      time: _nowTime(),
      proposalId: card.proposalId,
      proposalTitle: card.title,
      proposalStopsCount: card.stopsCount,
      proposalDurationMinutes: card.durationMinutes,
      proposalCoverUrl: card.coverUrl,
      proposalCard: card,
      placeChips: _placeChipsFromBlocks(proposal.blocks),
      catalogMatch: _catalogMatchFromBlocks(proposal.blocks),
      actions: const [],
      actionsLayout: _actionsLayoutFromBlocks(proposal.blocks),
    );
  }

  List<RouteChatPlaceChipData> _placeChipsFromBlocks(
    List<RouteChatBlock> blocks,
  ) {
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

  List<CatalogRouteItem> _catalogMatchFromBlocks(List<RouteChatBlock> blocks) {
    for (final block in blocks) {
      if (block is CatalogMatchBlock) {
        return block.routes;
      }
    }
    return const [];
  }

  ChatActionsLayout _actionsLayoutFromBlocks(List<RouteChatBlock> blocks) {
    for (final block in blocks) {
      if (block is ActionsBlock) {
        return block.layout;
      }
    }
    return ChatActionsLayout.wrap;
  }

  String? _actionsSheetTitleFromBlocks(List<RouteChatBlock> blocks) {
    for (final block in blocks) {
      if (block is ActionsBlock) {
        return block.sheetTitle;
      }
    }
    return null;
  }

  List<Map<String, String>> _actionsFromBlocks(List<RouteChatBlock> blocks) {
    return [
      for (final block in blocks)
        if (block is ActionsBlock)
          for (final action in block.actions)
            if ((action['id'] ?? '').isNotEmpty &&
                (action['label'] ?? '').isNotEmpty)
              {'id': action['id']!, 'label': action['label']!},
    ];
  }

  List<RouteChatRecommendationData> _recommendationsFromBlocks(
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

  List<RouteChatSliderData> _slidersFromBlocks(List<RouteChatBlock> blocks) {
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

  List<RouteChatToggleData> _togglesFromBlocks(List<RouteChatBlock> blocks) {
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

  Future<void> _acceptProposal(
    String proposalId, {
    required String message,
  }) async {
    try {
      final result = await ref
          .read(routeMatchRepositoryProvider)
          .acceptProposal(proposalId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      final routeId = result.routeId;
      if (routeId != null && routeId.isNotEmpty) {
        final userId = ref.read(sessionProvider).userId;
        unawaited(
          context.pushNamed(
            AppRouteNames.routeDetails,
            pathParameters: {'id': routeId},
            extra: RouteSummary(
              id: routeId,
              name: 'Сгенерированный маршрут',
              slug: 'generated',
              shortDescription: null,
              stopsCount: 0,
              ownerUserId: userId,
              publicationStatus: 'draft',
              visibility: 'private',
              source: 'generated',
            ),
          ),
        );
      }
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _onProposalReject(String proposalId) async {
    try {
      await ref.read(routeMatchRepositoryProvider).rejectProposal(proposalId);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          RouteChatMessage(
            fromAgent: true,
            text: 'Хорошо, соберём маршрут заново. Что изменить?',
            time: _nowTime(),
            actions: const [
              {'id': 'want_generate', 'label': 'Подбери маршрут'},
              {'id': 'pace_calm', 'label': 'Спокойный маршрут'},
              {'id': 'pace_active', 'label': 'Активный маршрут'},
            ],
          ),
        );
      });
      _scrollAiToEnd();
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _onProposalRefine(String _) {
    setState(() {
      _messages.add(
        RouteChatMessage(
          fromAgent: true,
          text: 'Что хотите изменить — город, темп, интересы или длительность?',
          time: _nowTime(),
          actions: const [
            {'id': 'want_generate', 'label': 'Подбери маршрут'},
            {'id': 'pace_calm', 'label': 'Хочу спокойно'},
            {'id': 'pace_active', 'label': 'Хочу активно'},
            {'id': 'interest_sea', 'label': 'Больше моря'},
            {'id': 'interest_mountains', 'label': 'Больше гор'},
            {'id': 'duration_d3_5', 'label': '3–5 дней'},
          ],
        ),
      );
    });
    _scrollAiToEnd();
  }

  Future<void> _onChatAction(String id, String label) async {
    if (_sending || _typing) {
      return;
    }
    if (id == 'want_generate') {
      await _sendAiMessage(
        textOverride: 'подбери маршрут',
        wantGenerate: true,
        actionId: id,
      );
      return;
    }
    if (id == 'build_custom_route') {
      await _sendAiMessage(textOverride: label, actionId: id);
      return;
    }
    if (id == 'clear_params') {
      await _sendAiMessage(textOverride: label, actionId: id);
      return;
    }
    await _sendAiMessage(textOverride: label, actionId: id);
  }

  static String _controlLabel(String id, Object value) => switch (id) {
    'budget_amount' => 'Бюджет ${value is num ? value.round() : value} ₽',
    'with_children' => value == true ? 'С детьми' : 'Без детей',
    'with_pets' => value == true ? 'С питомцами' : 'Без питомцев',
    _ => id,
  };

  /// Sends every slider/toggle value from one «Подтвердить» tap as a single
  /// chat turn on screen — each pending value still round-trips to the
  /// backend individually (one constraint patch per call), but only the
  /// last response is appended as a new agent bubble so confirming several
  /// controls at once doesn't reprint the conversation once per control.
  Future<void> _onConfirmControls(Map<String, Object> values) async {
    if (_sending || _typing || values.isEmpty) {
      return;
    }
    final entries = values.entries.toList(growable: false);
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      await _sendAiMessage(
        textOverride: _controlLabel(entry.key, entry.value),
        actionId: entry.key,
        controlValue: entry.value,
        silent: true,
        appendReply: i == entries.length - 1,
      );
    }
  }

  void _applyLocalConstraintPatch(String? actionId) {
    if (actionId == null || _sessionConstraints == null) {
      return;
    }
    final current = _sessionConstraints!;
    if (actionId == 'pace_calm') {
      _sessionConstraints = _copyParams(current, pace: RoutePace.calm);
    } else if (actionId == 'pace_moderate') {
      _sessionConstraints = _copyParams(current, pace: RoutePace.moderate);
    } else if (actionId == 'pace_active') {
      _sessionConstraints = _copyParams(current, pace: RoutePace.active);
    } else if (actionId == 'interest_sea') {
      _sessionConstraints = _copyParams(
        current,
        interests: _mergeInterests(current.interests, 'море'),
      );
    } else if (actionId == 'interest_mountains') {
      _sessionConstraints = _copyParams(
        current,
        interests: _mergeInterests(current.interests, 'горы'),
      );
    } else if (actionId == 'interest_food') {
      _sessionConstraints = _copyParams(
        current,
        interests: _mergeInterests(current.interests, 'еда'),
      );
    } else if (actionId == 'interest_romance') {
      _sessionConstraints = _copyParams(
        current,
        interests: _mergeInterests(current.interests, 'романтика'),
      );
    } else if (actionId == 'with_children') {
      _sessionConstraints = _copyParams(current, withChildren: true);
    } else if (actionId == 'transport_car') {
      _sessionConstraints = _copyParams(current, transportMode: 'car');
    } else if (actionId == 'transport_public') {
      _sessionConstraints = _copyParams(current, transportMode: 'public');
    } else if (actionId == 'transport_walk') {
      _sessionConstraints = _copyParams(current, transportMode: 'walk');
    } else if (actionId == 'transport_mixed') {
      _sessionConstraints = _copyParams(current, transportMode: 'mixed');
    } else if (actionId == 'duration_d1_2') {
      _sessionConstraints = _copyParams(
        current,
        duration: RouteDurationOption.d1_2,
      );
    } else if (actionId == 'duration_d3_5') {
      _sessionConstraints = _copyParams(
        current,
        duration: RouteDurationOption.d3_5,
      );
    } else if (actionId == 'duration_d6_7') {
      _sessionConstraints = _copyParams(
        current,
        duration: RouteDurationOption.d6_7,
      );
    } else if (actionId == 'duration_d7plus') {
      _sessionConstraints = _copyParams(
        current,
        duration: RouteDurationOption.d7plus,
      );
    } else if (actionId == 'people_1') {
      _sessionConstraints = _copyParams(current, people: 1);
    } else if (actionId == 'people_2') {
      _sessionConstraints = _copyParams(current, people: 2);
    } else if (actionId == 'people_3_plus') {
      _sessionConstraints = _copyParams(current, people: 3);
    }
  }

  List<String> _mergeInterests(List<String> current, String extra) {
    final out = [...current];
    if (!out.any((item) => item.toLowerCase() == extra.toLowerCase())) {
      out.add(extra);
    }
    return out;
  }

  RouteMatchParams _copyParams(
    RouteMatchParams source, {
    String? city,
    RouteDurationOption? duration,
    int? people,
    List<String>? interests,
    RoutePace? pace,
    String? transportMode,
    bool? withChildren,
  }) {
    return RouteMatchParams(
      city: city ?? source.city,
      tripType: source.tripType,
      duration: duration ?? source.duration,
      people: people ?? source.people,
      interests: interests ?? source.interests,
      pace: pace ?? source.pace,
      season: source.season,
      transportMode: transportMode ?? source.transportMode,
      dayKind: source.dayKind,
      budgetAmount: source.budgetAmount,
      paidOk: source.paidOk,
      withChildren: withChildren ?? source.withChildren,
      withPets: source.withPets,
      avoidCrowds: source.avoidCrowds,
      regionSlug: source.regionSlug,
    );
  }

  void _showChatFailure(AppFailure error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }

  void _onAiCtaPressed() {
    if (!widget.pixelReference && !ref.read(sessionProvider).travelPlusActive) {
      unawaited(context.push('/profile/settings/travel-plus'));
      return;
    }
    _setMode(RouteMatchMode.ai);
  }

  String _nowTime() {
    final now = TimeOfDay.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _sendAiMessage({
    String? textOverride,
    bool wantGenerate = false,
    String? actionId,
    Object? controlValue,
    bool silent = false,
    bool appendReply = true,
  }) async {
    final text = (textOverride ?? _aiController.text).trim();
    if (text.isEmpty || _sending || _typing) {
      return;
    }
    setState(() {
      _sending = true;
      // Controls (slider/toggle) reply silently — no fake "user typed" bubble.
      if (!silent) {
        _messages.add(
          RouteChatMessage(fromAgent: false, text: text, time: _nowTime()),
        );
      }
      if (textOverride == null) {
        _aiController.clear();
        _composerDirty = false;
      }
    });
    _scrollAiToEnd();

    final intent = classifyRouteMatchChatIntent(text);
    final useLocalCanned =
        intent == RouteMatchChatIntent.crisis ||
        intent == RouteMatchChatIntent.offTopic ||
        intent == RouteMatchChatIntent.injectionAttempt;
    if (useLocalCanned) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) {
        return;
      }
      setState(() {
        if (appendReply) {
          _messages.add(
            RouteChatMessage(
              fromAgent: true,
              text: cannedReplyForIntent(intent),
              time: _nowTime(),
              isCrisis: intent == RouteMatchChatIntent.crisis,
              actions: intent == RouteMatchChatIntent.offTopic
                  ? const [
                      {'id': 'want_generate', 'label': 'Подбери маршрут'},
                      {'id': 'pace_calm', 'label': 'Хочу спокойно'},
                      {'id': 'interest_sea', 'label': 'Больше моря'},
                    ]
                  : const [],
            ),
          );
        }
        _sending = false;
      });
      _scrollAiToEnd();
      return;
    }

    setState(() => _typing = true);
    _scrollAiToEnd();
    try {
      if (_chatSessionId == null) {
        await _ensureChatSession();
      }
      final sessionId = _chatSessionId;
      if (sessionId == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _typing = false;
          _sending = false;
        });
        return;
      }
      final result = await ref
          .read(routeMatchRepositoryProvider)
          .postMessage(
            sessionId: sessionId,
            text: text,
            wantGenerate: wantGenerate,
            actionId: actionId,
            controlValue: controlValue,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _typing = false;
        _sending = false;
        _applyLocalConstraintPatch(actionId);
        if (appendReply) {
          _messages.add(_agentMessageFromResult(result));
        }
      });
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _typing = false;
        _sending = false;
      });
      _showChatFailure(error);
    }
    _scrollAiToEnd();
  }

  void _scrollAiToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_aiScroll.hasClients) {
        return;
      }
      final target = _aiScroll.position.maxScrollExtent;
      if (!animate) {
        _aiScroll.jumpTo(target);
        return;
      }
      unawaited(
        _aiScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _scrollAiToDemoOffset() {
    if (!_aiScroll.hasClients) {
      return;
    }
    // Slightly scrolled so the first agent bubble is partially clipped.
    _aiScroll.jumpTo(18);
  }

  @override
  Widget build(BuildContext context) {
    final scale = RouteBuilderScale.of(context);
    double px(double value) => scale.px(value);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final shellNavPad = px(56 + 10) + bottom;
    final session = ref.watch(sessionProvider);
    final showAdvanced =
        session.advancedFiltersEnabled || session.travelPlusActive;

    final body = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ScrollConfiguration(
        behavior: const RouteBuilderScrollBehavior(),
        child: Scaffold(
          backgroundColor: RouteBuilderDesignTokens.background,
          resizeToAvoidBottomInset: true,
          extendBody: true,
          extendBodyBehindAppBar: false,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: RouteBuilderDesignTokens.maxContentWidth,
                    ),
                    child: _mode == RouteMatchMode.ai
                        ? RouteAiChatView(
                            header: _buildTopChrome(px),
                            px: px,
                            messages: _messages,
                            scrollController: _aiScroll,
                            composerController: _aiController,
                            composerFocus: _aiFocus,
                            typing: _typing || _sessionStarting,
                            canSend:
                                _composerDirty &&
                                _aiController.text.trim().isNotEmpty,
                            onChanged: (value) {
                              setState(() {
                                _composerDirty = value.trim().isNotEmpty;
                              });
                            },
                            onSend: () {
                              unawaited(_sendAiMessage());
                            },
                            onProposalCreate: (id) {
                              unawaited(
                                _acceptProposal(id, message: 'Маршрут создан'),
                              );
                            },
                            onProposalSaveDraft: (id) {
                              unawaited(
                                _acceptProposal(
                                  id,
                                  message: 'Маршрут сохранён в черновик',
                                ),
                              );
                            },
                            onProposalRefine: _onProposalRefine,
                            onProposalReject: (id) {
                              unawaited(_onProposalReject(id));
                            },
                            onProposalViewMap: (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Карта маршрута появится в одном из '
                                    'следующих обновлений',
                                  ),
                                ),
                              );
                            },
                            onChatAction: (id, label) {
                              unawaited(_onChatAction(id, label));
                            },
                            onOpenCatalogRoute: (routeId) {
                              unawaited(context.push('/routes/$routeId'));
                            },
                            onControlChanged: (values) {
                              unawaited(_onConfirmControls(values));
                            },
                            onNewChat: () {
                              unawaited(_startNewChat());
                            },
                            bottomInset: px(8),
                          )
                        : _buildParams(px, shellNavPad, showAdvanced),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: AppScrollBrandBar(
                    topInset: top,
                    progress: _appBarProgress,
                    onBack: _goBack,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AppEdgeBackGesture(onBack: _goBack, child: body);
  }

  Widget _buildParams(RoutePx px, double bottomPad, bool showAdvanced) {
    final suggestions = _filteredSuggestions;
    return ListView(
      key: const ValueKey('route-match-params-scroll'),
      controller: _paramsScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottomPad + px(10)),
      children: [
        _buildTopChrome(px),
        SizedBox(height: px(15)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: CitySearchField(
            px: px,
            controller: _cityController,
            focusNode: _cityFocus,
            hasError: _cityError,
            onChanged: _onCityTextChanged,
            onClear: _clearCity,
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          SizedBox(height: px(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: px(16)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RouteBuilderDesignTokens.surface,
                borderRadius: BorderRadius.circular(px(12)),
                border: Border.all(
                  color: RouteBuilderDesignTokens.lightBorder,
                  width: px(1),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < suggestions.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: px(1),
                        color: RouteBuilderDesignTokens.lightBorder,
                      ),
                    ListTile(
                      dense: true,
                      title: Text(
                        suggestions[i],
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: px(14),
                          color: RouteBuilderDesignTokens.textPrimary,
                        ),
                      ),
                      onTap: () => _selectCity(suggestions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: px(9)),
        CityQuickChips(
          px: px,
          cities: _popularCities,
          selected: _city,
          onSelected: _selectCity,
        ),
        SizedBox(height: px(20)),
        TravelTypeSelector(
          px: px,
          value: _tripType,
          onChanged: (value) => setState(() => _tripType = value),
        ),
        SizedBox(height: px(22)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: DurationSelector(
            px: px,
            value: _duration,
            onChanged: (value) => setState(() => _duration = value),
          ),
        ),
        SizedBox(height: px(22)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: PeopleCounter(
            px: px,
            value: _people,
            onChanged: (value) => setState(() => _people = value),
          ),
        ),
        SizedBox(height: px(21)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: InterestSelector(
            px: px,
            options: _interestOptions,
            selected: _interests,
            onToggle: (interest) => setState(() {
              if (_interests.contains(interest)) {
                _interests.remove(interest);
              } else {
                _interests.add(interest);
              }
            }),
          ),
        ),
        SizedBox(height: px(21)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: TravelPaceSelector(
            px: px,
            value: _pace,
            onChanged: (value) => setState(() => _pace = value),
          ),
        ),
        SizedBox(height: px(21)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: SeasonSelector(
            px: px,
            value: _season,
            onChanged: (value) => setState(() => _season = value),
          ),
        ),
        SizedBox(height: px(21)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: TransportSelector(
            px: px,
            value: _transportMode,
            onChanged: (value) => setState(() => _transportMode = value),
          ),
        ),
        SizedBox(height: px(21)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: DayKindSelector(
            px: px,
            value: _dayKind,
            onChanged: (value) => setState(() => _dayKind = value),
          ),
        ),
        if (showAdvanced) ...[
          SizedBox(height: px(21)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: px(16)),
            child: AdvancedMatchOptions(
              px: px,
              budgetController: _budgetController,
              withChildren: _withChildren,
              withPets: _withPets,
              avoidCrowds: _avoidCrowds,
              onWithChildrenChanged: (value) =>
                  setState(() => _withChildren = value),
              onWithPetsChanged: (value) => setState(() => _withPets = value),
              onAvoidCrowdsChanged: (value) =>
                  setState(() => _avoidCrowds = value),
            ),
          ),
        ],
        SizedBox(height: px(17)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: RouteActionButtons(
            px: px,
            hasTravelPlus:
                widget.pixelReference ||
                ref.watch(sessionProvider).travelPlusActive,
            matching: _matching,
            onMatch: () {
              unawaited(_onMatchPressed());
            },
            onAi: _onAiCtaPressed,
          ),
        ),
      ],
    );
  }

  Widget _buildTopChrome(RoutePx px) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RouteHeader(px: px),
        SizedBox(height: px(17)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: RouteModeSwitcher(
            key: _modeSwitcherKey,
            px: px,
            mode: _mode,
            onChanged: _setMode,
          ),
        ),
      ],
    );
  }
}
