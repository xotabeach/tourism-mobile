import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_notifier.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_mode_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';
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
  bool _composerDirty = false;
  double _appBarProgress = 0;
  double _lastViewInset = 0;
  List<RouteChatMessage> _pixelMessages = const [];

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
    if (widget.pixelReference) {
      _pixelMessages = const [
        RouteChatMessage(
          fromAgent: true,
          text: RouteBuilderDemoState.pixelAgentGreeting,
          time: '17:53',
        ),
        RouteChatMessage(
          fromAgent: false,
          text: RouteBuilderDemoState.pixelUserMessage,
          time: '17:52',
        ),
        RouteChatMessage(
          fromAgent: true,
          text: RouteBuilderDemoState.pixelAgentShort,
          time: '17:53',
        ),
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAiModeProvider();
      if (widget.pixelReference && _mode == RouteMatchMode.ai) {
        _scrollAiToDemoOffset();
      }
      if (resume != null) {
        unawaited(_resumeSession(resume));
      }
    });
  }

  /// Chat state lives in [RouteMatchNotifier], so resuming a session from the
  /// history screen delegates there instead of rebuilding the transcript in
  /// this widget's own state.
  Future<void> _resumeSession(RoutePlanningSession session) async {
    if (!ref.read(sessionProvider).travelPlusActive) {
      unawaited(context.push('/profile/settings/travel-plus'));
      return;
    }
    await ref.read(routeMatchNotifierProvider.notifier).resumeSession(session);
    if (!mounted) {
      return;
    }
    _scrollAiToEnd(animate: false);
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
    if (mode == RouteMatchMode.ai && !widget.pixelReference) {
      unawaited(
        ref
            .read(routeMatchNotifierProvider.notifier)
            .ensureSession(_draftParams()),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncAppBarFromActiveScroll(),
    );
  }

  RouteMatchNotifier get _chat => ref.read(routeMatchNotifierProvider.notifier);

  RouteMatchParams _draftParams() {
    final city = _city?.trim();
    final hasCity = city != null && city.isNotEmpty;
    return _buildMatchParams(city: hasCity ? city : 'Крым');
  }

  Future<void> _startNewChat() async {
    if (widget.pixelReference) {
      return;
    }
    _aiController.clear();
    setState(() => _composerDirty = false);
    await _chat.startNewChat(_draftParams());
    _scrollAiToEnd();
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
    final params = _buildMatchParams(city: city);
    final result = await _chat.match(params);
    if (!mounted || result == null) {
      return;
    }
    ref.read(lastRouteMatchResultProvider.notifier).state = result;
    ref.read(lastRouteMatchParamsProvider.notifier).state = params;
    unawaited(context.pushNamed(AppRouteNames.routeMatchResults));
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

  Future<void> _acceptProposal(
    String proposalId, {
    required String message,
  }) async {
    final result = await _chat.acceptProposal(proposalId);
    if (!mounted || result == null) {
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
  }

  Future<void> _onProposalReject(String proposalId) async {
    await _chat.rejectProposal(proposalId);
    _scrollAiToEnd();
  }

  void _onProposalRefine(String _) {
    _chat.refineProposal();
    _scrollAiToEnd();
  }

  Future<void> _onChatAction(String id, String label) {
    return _chat.onChatAction(id, label);
  }

  Future<void> _onConfirmControls(Map<String, Object> values) {
    return _chat.confirmControls(values);
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

  Future<void> _sendAiMessage() async {
    final text = _aiController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _aiController.clear();
    setState(() => _composerDirty = false);
    await _chat.sendMessage(text: text, draftForSession: _draftParams());
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
    final chat = ref.watch(routeMatchNotifierProvider);
    ref.listen<RouteMatchChatState>(routeMatchNotifierProvider, (
      previous,
      next,
    ) {
      if (widget.pixelReference) {
        return;
      }
      if (previous?.messages.length != next.messages.length ||
          previous?.typing != next.typing ||
          previous?.sessionStarting != next.sessionStarting) {
        _scrollAiToEnd();
      }
      final failure = next.lastFailure;
      if (failure != null && failure != previous?.lastFailure) {
        _showChatFailure(failure);
        unawaited(
          Future<void>.microtask(
            () => ref.read(routeMatchNotifierProvider.notifier).clearFailure(),
          ),
        );
      }
    });
    final messages = widget.pixelReference ? _pixelMessages : chat.messages;

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
                            messages: messages,
                            scrollController: _aiScroll,
                            composerController: _aiController,
                            composerFocus: _aiFocus,
                            typing: chat.typing || chat.sessionStarting,
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
                        : _buildParams(
                            px,
                            shellNavPad,
                            showAdvanced,
                            matching: chat.matching,
                          ),
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

  Widget _buildParams(
    RoutePx px,
    double bottomPad,
    bool showAdvanced, {
    required bool matching,
  }) {
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
            matching: matching,
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
