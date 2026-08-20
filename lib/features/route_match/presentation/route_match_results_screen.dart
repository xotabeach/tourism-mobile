import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// Результат подбора: ranked ideal/close с backend match + CTA генерации.
class RouteMatchResultsScreen extends ConsumerStatefulWidget {
  const RouteMatchResultsScreen({super.key});

  static const routePath = 'results';

  @override
  ConsumerState<RouteMatchResultsScreen> createState() =>
      _RouteMatchResultsScreenState();
}

class _RouteMatchResultsScreenState
    extends ConsumerState<RouteMatchResultsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'match-search');
  Timer? _searchDebounce;
  var _searchQuery = '';
  var _searchFocused = false;
  var _generating = false;

  bool get _searchActive => _searchFocused || _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) {
        setState(() => _searchFocused = _searchFocus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      final query = value.trim();
      setState(() => _searchQuery = query);
    });
  }

  Future<void> _onGeneratePressed() async {
    if (_generating) {
      return;
    }
    final params = ref.read(lastRouteMatchParamsProvider);
    if (params == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выполните подбор по параметрам')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(routeMatchRepositoryProvider)
          .generate(channel: 'form', params: params);
      if (!mounted) {
        return;
      }
      final routeId = result.routeId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            routeId != null ? 'Маршрут создан' : 'Черновик маршрута готов',
          ),
        ),
      );
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
      } else {
        context.pop();
      }
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final match = ref.watch(lastRouteMatchResultProvider);

    if (match == null) {
      return Scaffold(
        backgroundColor: AppColors.pageSurface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Сначала выполните подбор по параметрам'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(RouteMatchScreen.routePath),
                  child: const Text('К подбору'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ideal = match.idealRoutes;
    final close = match.closeRoutes;
    final filtered = [...ideal, ...close];
    final totalLabel = filtered.length;

    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Результаты подбора ($totalLabel)',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppSearchFilterRow(
                    hintText: 'Место или маршрут из подборки',
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onSearchChanged: _onSearchChanged,
                    onSearchClear: () {
                      _searchDebounce?.cancel();
                      setState(() => _searchQuery = '');
                    },
                    onFilterTap: () {},
                  ),
                  if (match.offerGenerate) ...[
                    const SizedBox(height: 14),
                    _GenerateOfferCard(
                      generating: _generating,
                      onPressed: () {
                        unawaited(_onGeneratePressed());
                      },
                    ),
                  ],
                  if (!_searchActive && ideal.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Идеально для вас:',
                      style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          if (_searchActive)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverToBoxAdapter(
                child: InPlaceSearchBody(
                  query: _searchQuery,
                  scope: SearchScope.routes,
                  localRoutes: filtered,
                  onQueryFromHistory: (value) {
                    _searchController.text = value;
                    _onSearchChanged(value);
                  },
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Подходящих маршрутов в каталоге не нашлось',
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Можно сгенерировать персональный маршрут по вашим '
                      'параметрам — лимиты зависят от плана (free / Тревел+).',
                      textAlign: TextAlign.center,
                      style: AppTypography.greetingSubtitle.copyWith(
                        color: AppColors.secondaryInk,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _generating
                          ? null
                          : () {
                              unawaited(_onGeneratePressed());
                            },
                      child: _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сгенерировать маршрут'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: ideal.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    RouteHeroCard(route: ideal[index], height: 295),
              ),
            ),
            if (close.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Близки к вашему идеалу:',
                    style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList.separated(
                  itemCount: close.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      RouteHeroCard(route: close[index], height: 295),
                ),
              ),
            ] else
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }
}

class _GenerateOfferCard extends StatelessWidget {
  const _GenerateOfferCard({required this.onPressed, this.generating = false});

  final VoidCallback onPressed;
  final bool generating;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.controlSurface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Нет идеального совпадения — можно сгенерировать маршрут',
                style: AppTypography.greetingSubtitle.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: generating ? null : onPressed,
              child: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
