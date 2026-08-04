import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/components/app_brand_bar.dart';
import 'package:tourism_mobile/core/design/components/app_edge_back_gesture.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_mode_provider.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Подбор маршрута — форма по параметрам + чат «Подбор с ИИ».
///
/// [pixelReference] loads golden/demo chat content only for visual tests.
class RouteMatchScreen extends ConsumerStatefulWidget {
  const RouteMatchScreen({
    super.key,
    this.pixelReference = false,
    this.initialMode = RouteMatchMode.params,
  });

  static const routePath = '/match';

  /// Separates golden/demo fixtures from production chat logic.
  final bool pixelReference;

  final RouteMatchMode initialMode;

  @override
  ConsumerState<RouteMatchScreen> createState() => _RouteMatchScreenState();
}

class _RouteMatchScreenState extends ConsumerState<RouteMatchScreen> {
  late RouteMatchMode _mode;
  String? _city;
  RouteTripType? _tripType = RouteTripType.romance;
  RouteDurationOption _duration = RouteDurationOption.d3_5;
  int _people = 2;
  final Set<String> _interests = {'Природа'};
  RoutePace _pace = RoutePace.calm;

  final _cityController = TextEditingController();
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
  int _aiAttemptsLeft = 3;
  double _appBarProgress = 0;

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
    _paramsScroll.addListener(_syncAppBarFromActiveScroll);
    _aiScroll.addListener(_syncAppBarFromActiveScroll);
    _mode = widget.initialMode;
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
        : [
            const RouteChatMessage(
              fromAgent: true,
              text:
                  'Здравствуй Путник! Что должно быть в твоём идеальном маршруте?',
              time: '17:53',
            ),
          ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAiModeProvider();
      if (widget.pixelReference && _mode == RouteMatchMode.ai) {
        _scrollAiToDemoOffset();
      }
    });
  }

  @override
  void deactivate() {
    if (ref.read(routeMatchAiModeProvider)) {
      ref.read(routeMatchAiModeProvider.notifier).state = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _cityFocus.dispose();
    _aiController.dispose();
    _aiFocus.dispose();
    _paramsScroll
      ..removeListener(_syncAppBarFromActiveScroll)
      ..dispose();
    _aiScroll
      ..removeListener(_syncAppBarFromActiveScroll)
      ..dispose();
    super.dispose();
  }

  void _syncAiModeProvider() {
    final hideNav = _mode == RouteMatchMode.ai;
    if (ref.read(routeMatchAiModeProvider) != hideNav) {
      ref.read(routeMatchAiModeProvider.notifier).state = hideNav;
    }
  }

  void _setMode(RouteMatchMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    _syncAiModeProvider();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncAppBarFromActiveScroll(),
    );
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
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRouteNames.routeMatchResults));
    } finally {
      if (mounted) {
        setState(() => _matching = false);
      }
    }
  }

  void _onAiCtaPressed() {
    if (_aiAttemptsLeft <= 0) {
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

  Future<void> _sendAiMessage() async {
    final text = _aiController.text.trim();
    if (text.isEmpty || _sending || _typing) {
      return;
    }
    setState(() {
      _sending = true;
      _messages.add(
        RouteChatMessage(fromAgent: false, text: text, time: _nowTime()),
      );
      _aiController.clear();
      _composerDirty = false;
    });
    _scrollAiToEnd();

    if (routeMatchLooksLikeSelfHarm(text)) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          RouteChatMessage(
            fromAgent: true,
            text: routeMatchCrisisSupportReply,
            time: _nowTime(),
            isCrisis: true,
          ),
        );
        _sending = false;
      });
      _scrollAiToEnd();
      return;
    }

    setState(() => _typing = true);
    _scrollAiToEnd();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    final contextBits = <String>[
      if (_city != null) 'старт: $_city',
      if (_tripType != null) 'тип: ${_tripType!.name}',
      'длительность: ${_duration.name}',
      'люди: $_people',
      if (_interests.isNotEmpty) 'интересы: ${_interests.join(", ")}',
      'темп: ${_pace.name}',
    ].join('; ');

    setState(() {
      _typing = false;
      _sending = false;
      _messages.add(
        RouteChatMessage(
          fromAgent: true,
          text:
              'Принял. Учту пожелания и параметры ($contextBits). '
              'Соберу спокойный черновик маршрута без опасных активностей.',
          time: _nowTime(),
        ),
      );
      if (_aiAttemptsLeft > 0) {
        _aiAttemptsLeft -= 1;
      }
    });
    _scrollAiToEnd();
  }

  void _scrollAiToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_aiScroll.hasClients) {
        return;
      }
      unawaited(
        _aiScroll.animateTo(
          _aiScroll.position.maxScrollExtent,
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
                            typing: _typing,
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
                            bottomInset: shellNavPad,
                          )
                        : _buildParams(px, shellNavPad),
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

  Widget _buildParams(RoutePx px, double bottomPad) {
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
        SizedBox(height: px(17)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: RouteActionButtons(
            px: px,
            attemptsLeft: _aiAttemptsLeft,
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
