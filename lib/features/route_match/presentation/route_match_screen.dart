import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/domain/crimea_cities.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/connectivity_provider.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_notifier.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_mode_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_proposal_preview_screen.dart';
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
  String? _startQuery;
  RouteLocationSuggestion? _selectedStartLocation;
  List<RouteLocationSuggestion> _locationSuggestions = const [];
  Timer? _locationSearchDebounce;
  int _locationSearchGeneration = 0;
  bool _locationSearchLoading = false;
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
  bool _paidOk = false;

  final _startController = TextEditingController();
  final _budgetController = TextEditingController();
  final _startFocus = FocusNode(debugLabel: 'route-match-start-location');
  final _aiController = TextEditingController();
  final _aiFocus = FocusNode(debugLabel: 'route-match-ai');
  final _paramsScroll = ScrollController();
  final _aiScroll = ScrollController();
  final _modeSwitcherKey = GlobalKey();

  bool _composerDirty = false;
  double _appBarProgress = 0;
  double _lastViewInset = 0;
  List<RouteChatMessage> _pixelMessages = const [];

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
      } else if (_mode == RouteMatchMode.ai && !widget.pixelReference) {
        unawaited(_chat.ensureSession(_draftParams()));
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
    _locationSearchDebounce?.cancel();
    _startController.dispose();
    _budgetController.dispose();
    _startFocus.dispose();
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

  /// Both modes are one screen on purpose: the selector morphs between them
  /// and the layout swaps in place. Pushing chat as its own page bought an
  /// interactive iOS pop but replaced that morph with a whole screen sliding
  /// in, which is not what this screen is designed around.
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

  RouteMatchParams _draftParams() => _buildMatchParams();

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
    // Same gesture, same destination in both modes — chat is a mode of this
    // screen, not a page stacked on top of it, so there is nothing mode
    // specific left to pop.
    _aiFocus.unfocus();
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

  void _selectStartLocation(RouteLocationSuggestion location) {
    _locationSearchDebounce?.cancel();
    _locationSearchGeneration += 1;
    setState(() {
      _startQuery = location.name;
      _selectedStartLocation = location;
      _startController.text = location.name;
      _startController.selection = TextSelection.collapsed(
        offset: location.name.length,
      );
      _locationSuggestions = const [];
      _locationSearchLoading = false;
    });
    _startFocus.unfocus();
  }

  void _selectStartText(String value) {
    _locationSearchDebounce?.cancel();
    _locationSearchGeneration += 1;
    setState(() {
      _startQuery = value;
      _selectedStartLocation = null;
      _startController.text = value;
      _startController.selection = TextSelection.collapsed(
        offset: value.length,
      );
      _locationSuggestions = const [];
      _locationSearchLoading = false;
    });
    _startFocus.unfocus();
  }

  void _onStartTextChanged(String value) {
    final query = value.trim();
    _locationSearchDebounce?.cancel();
    final generation = ++_locationSearchGeneration;
    setState(() {
      _startQuery = query.isEmpty ? null : query;
      _selectedStartLocation = null;
      _locationSuggestions = const [];
      _locationSearchLoading = query.length >= 2;
    });
    if (query.length < 2) {
      return;
    }
    _locationSearchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_loadLocationSuggestions(query, generation)),
    );
  }

  Future<void> _loadLocationSuggestions(String query, int generation) async {
    try {
      final suggestions = await ref
          .read(routeMatchRepositoryProvider)
          .searchLocations(query);
      if (!mounted || generation != _locationSearchGeneration) {
        return;
      }
      setState(() {
        _locationSuggestions = suggestions;
        _locationSearchLoading = false;
      });
    } on Object {
      // Autocomplete is an aid, not a gate: a typed place can still be sent
      // to the route service and an empty field means a flexible start.
      if (!mounted || generation != _locationSearchGeneration) {
        return;
      }
      setState(() {
        _locationSuggestions = const [];
        _locationSearchLoading = false;
      });
    }
  }

  void _clearStart() {
    _locationSearchDebounce?.cancel();
    _locationSearchGeneration += 1;
    setState(() {
      _startQuery = null;
      _selectedStartLocation = null;
      _startController.clear();
      _locationSuggestions = const [];
      _locationSearchLoading = false;
    });
  }

  Future<void> _onMatchPressed() async {
    final params = _buildMatchParams();
    final result = await _chat.match(params);
    if (!mounted || result == null) {
      return;
    }
    ref.read(lastRouteMatchResultProvider.notifier).state = result;
    ref.read(lastRouteMatchParamsProvider.notifier).state = params;
    unawaited(context.pushNamed(AppRouteNames.routeMatchResults));
  }

  RouteMatchParams _buildMatchParams() {
    final session = ref.read(sessionProvider);
    final advanced = session.advancedFiltersEnabled || session.travelPlusActive;
    final budgetRaw = _budgetController.text.trim();
    final budget = budgetRaw.isEmpty ? null : int.tryParse(budgetRaw);
    final startQuery = _startQuery?.trim();
    final hasStart = startQuery != null && startQuery.isNotEmpty;
    final selected = _selectedStartLocation;
    return RouteMatchParams(
      startQuery: hasStart ? startQuery : null,
      startLocalityId: selected?.isLocality == true ? selected?.id : null,
      startPlaceId: selected?.isPlace == true ? selected?.id : null,
      flexibleStart: !hasStart,
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
      paidOk: advanced && _paidOk ? true : null,
    );
  }

  /// Keeps a finished chat from being a dead end: every route it proposed
  /// goes to drafts in one tap, so the work survives the session.
  Future<void> _saveAllProposalsToDrafts(
    List<RouteChatMessage> messages,
  ) async {
    final ids = <String>{for (final message in messages) ?message.proposalId};
    if (ids.isEmpty) {
      return;
    }
    var saved = 0;
    for (final id in ids) {
      final result = await _chat.acceptProposal(id);
      if (!mounted) {
        return;
      }
      if (result != null) {
        saved++;
      }
    }
    if (!mounted) {
      return;
    }
    showAppNotice(
      context,
      saved == 0
          ? 'Не удалось сохранить маршруты'
          : 'Маршруты сохранены в черновики: $saved',
    );
  }

  Future<void> _acceptProposal(
    String proposalId, {
    required String message,
    bool startExecution = false,
  }) async {
    final result = await _chat.acceptProposal(proposalId);
    if (!mounted || result == null) {
      return;
    }
    showAppNotice(context, message);
    final routeId = result.routeId;
    if (startExecution && routeId != null && routeId.isNotEmpty) {
      unawaited(
        context.pushNamed(
          AppRouteNames.routeExecution,
          pathParameters: {'id': routeId},
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

  Future<bool> _onConfirmControls(Map<String, Object> values) {
    return _chat.confirmControls(values);
  }

  void _showChatFailure(AppFailure error) {
    if (!mounted) {
      return;
    }
    showAppNotice(context, error.message);
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
    if (!widget.pixelReference && !ref.watch(isOnlineProvider)) {
      return Scaffold(
        backgroundColor: RouteBuilderDesignTokens.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.accentBlue,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Недоступно в офлайн-режиме',
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Подбор маршрута требует подключения к интернету.',
                    textAlign: TextAlign.center,
                    style: AppTypography.greetingSubtitle.copyWith(
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Назад'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
                                _acceptProposal(
                                  id,
                                  message: 'Маршрут создан',
                                  startExecution: true,
                                ),
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
                            onProposalViewMap: (id) {
                              unawaited(
                                Navigator.of(context).push(
                                  CupertinoPageRoute<void>(
                                    builder: (_) => RouteProposalPreviewScreen(
                                      proposalId: id,
                                    ),
                                  ),
                                ),
                              );
                            },
                            onChatAction: (id, label) {
                              unawaited(_onChatAction(id, label));
                            },
                            onOpenCatalogRoute: (routeId) {
                              unawaited(context.push('/route/$routeId'));
                            },
                            onControlChanged: _onConfirmControls,
                            onNewChat: () {
                              unawaited(_startNewChat());
                            },
                            sessionFull: chat.sessionFull,
                            limitNoticeDismissed: chat.limitNoticeDismissed,
                            onDismissLimitNotice: _chat.dismissLimitNotice,
                            onShowLimitNotice: _chat.showLimitNotice,
                            onSaveAllDrafts: () {
                              unawaited(_saveAllProposalsToDrafts(messages));
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

    // One gesture for both modes: chat is a mode of this screen, not a page
    // over it, so there is no Navigator underneath to own the swipe.
    return AppEdgeBackGesture(onBack: _goBack, child: body);
  }

  Widget _buildParams(
    RoutePx px,
    double bottomPad,
    bool showAdvanced, {
    required bool matching,
  }) {
    final suggestions = _locationSuggestions;
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
          child: StartLocationSearchField(
            px: px,
            controller: _startController,
            focusNode: _startFocus,
            loading: _locationSearchLoading,
            onChanged: _onStartTextChanged,
            onClear: _clearStart,
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          SizedBox(height: px(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: px(16)),
            child: Material(
              color: RouteBuilderDesignTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(px(12)),
                side: BorderSide(
                  color: RouteBuilderDesignTokens.lightBorder,
                  width: px(1),
                ),
              ),
              clipBehavior: Clip.antiAlias,
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
                      leading: Icon(
                        suggestions[i].isPlace
                            ? Icons.place_outlined
                            : Icons.location_city_outlined,
                        size: px(20),
                        color: RouteBuilderDesignTokens.primaryBlue,
                      ),
                      title: Text(
                        suggestions[i].name,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: px(14),
                          color: RouteBuilderDesignTokens.textPrimary,
                        ),
                      ),
                      subtitle: suggestions[i].subtitle == null
                          ? null
                          : Text(
                              suggestions[i].subtitle!,
                              style: RouteBuilderDesignTokens.rubik(
                                fontSize: px(12),
                                color: RouteBuilderDesignTokens.textSecondary,
                              ),
                            ),
                      trailing: Icon(
                        Icons.north_west_rounded,
                        size: px(17),
                        color: RouteBuilderDesignTokens.textSecondary,
                      ),
                      onTap: () => _selectStartLocation(suggestions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: px(9)),
        StartLocationQuickChips(
          px: px,
          locations: popularCrimeaStartLocations,
          selected: _startQuery,
          onSelected: _selectStartText,
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
              paidOk: _paidOk,
              onWithChildrenChanged: (value) =>
                  setState(() => _withChildren = value),
              onWithPetsChanged: (value) => setState(() => _withPets = value),
              onAvoidCrowdsChanged: (value) =>
                  setState(() => _avoidCrowds = value),
              onPaidOkChanged: (value) => setState(() => _paidOk = value),
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
