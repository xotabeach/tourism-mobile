import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RouteDetailsScreen extends ConsumerStatefulWidget {
  const RouteDetailsScreen({
    required this.routeId,
    this.initialRoute,
    super.key,
  });

  static const routePath = '/routes/:id';

  final String routeId;
  final RouteSummary? initialRoute;

  @override
  ConsumerState<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends ConsumerState<RouteDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _galleryController;

  int? _selectedStop;

  @override
  void initState() {
    super.initState();
    _galleryController = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
    );
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleGallery() {
    _settleGallery(_galleryController.value < 0.5 ? 1 : 0);
  }

  void _settleGallery(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _galleryController.value = target;
      return;
    }
    final remaining = (target - _galleryController.value).abs();
    _galleryController.duration = Duration(
      milliseconds: (220 + 120 * remaining).round(),
    );
    unawaited(
      _galleryController.animateTo(target, curve: AppMotion.emphasizedCurve),
    );
  }

  void _selectStop(int index) => setState(() => _selectedStop = index);

  void _openPlace(RouteStop stop) => context.go('/places/${stop.placeId}');

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(routeDetailProvider(widget.routeId));

    return Scaffold(
      backgroundColor: AppColors.elevatedSurface,
      body: routeAsync.when(
        data: _buildContent,
        loading: () => widget.initialRoute == null
            ? const Center(child: CircularProgressIndicator())
            : _buildInitialContent(widget.initialRoute!),
        error: (_, _) => AppAsyncErrorView(
          onRetry: () => ref.invalidate(routeDetailProvider(widget.routeId)),
        ),
      ),
    );
  }

  Widget _buildContent(RouteDetail route) {
    final config = ref.watch(appConfigProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const ValueKey('route-details-list'),
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      children: [
        AnimatedBuilder(
          animation: _galleryController,
          builder: (context, _) => RouteMediaHeader(
            images: _galleryImages(config, route),
            expansionProgress: _galleryController.value,
            onToggle: _toggleGallery,
            heroTag: 'route-cover-${route.id}',
            actions: [
              _HeaderAction(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Назад',
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              _HeaderAction(
                iconAsset: AppIconography.heart,
                semanticLabel: 'В избранное',
                onPressed: () => _showSoon('Избранное'),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.ios_share_rounded,
                semanticLabel: 'Поделиться',
                onPressed: () => _showSoon('Поделиться маршрутом'),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                iconAsset: AppIconography.download,
                semanticLabel: 'Скачать офлайн',
                onPressed: () => _showSoon('Офлайн-режим'),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.elevatedSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 178 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorRow(
                    name: route.authorLabel ?? 'КрымТрип редакция',
                    subtitle: 'Продвинутый пешеход',
                    onMore: () => _showSoon('Меню маршрута'),
                  ),
                  const _SectionDivider(),
                  Text(
                    route.name,
                    key: const ValueKey('route-details-title'),
                    style: AppTypography.routeTitle.copyWith(
                      fontSize: 24,
                      height: 1.14,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  if (route.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      route.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.42,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _AudioGuideCard(
                    title: route.name,
                    author: route.authorLabel ?? 'КрымТрип редакция',
                    image: _routeCover(config, route),
                    onPlay: () => _showSoon('Аудиогид'),
                  ),
                  const SizedBox(height: 16),
                  const _RouteTagsRow(
                    tags: ['Горы', 'С детьми', 'Пешком', 'Круглый год'],
                  ),
                  const SizedBox(height: 16),
                  _RouteFacts(route: route),
                  const _SectionDivider(),
                  const _SectionTitle('Карта маршрута:'),
                  const SizedBox(height: 14),
                  RouteMapPreview(
                    stops: route.stops,
                    selectedIndex: _selectedStop,
                    onPinTap: _selectStop,
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Остановки:'),
                  const SizedBox(height: 6),
                  for (var index = 0; index < route.stops.length; index++)
                    _StopRow(
                      stop: route.stops[index],
                      selected: _selectedStop == index,
                      showDivider: index != route.stops.length - 1,
                      onNumberTap: () => _selectStop(index),
                      onOpen: () => _openPlace(route.stops[index]),
                    ),
                  _SimilarRoutesSection(currentRouteId: route.id),
                  const SizedBox(height: 22),
                  const _RatingRow(rating: '4,9', topLabel: '# ТОП 153'),
                  const SizedBox(height: 14),
                  for (final review in _designReviews) ...[
                    _ReviewCard(review: review),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialContent(RouteSummary route) {
    final config = ref.watch(appConfigProvider);
    return ColoredBox(
      color: AppColors.elevatedSurface,
      child: Column(
        children: [
          RouteMediaHeader(
            images: [_routeCover(config, route)],
            expansionProgress: 0,
            onToggle: () {},
            heroTag: 'route-cover-${route.id}',
            actions: [
              _HeaderAction(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Назад',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 180,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.controlSurface,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.controlSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature появится позже')));
  }

  List<ImageProvider> _galleryImages(AppConfig config, RouteDetail route) {
    final cover = _routeCover(config, route);
    final rest = AppImages.routeFallbacks
        .where((asset) => asset != route.coverImageUrl)
        .map<ImageProvider>(AssetImage.new);
    return [cover, ...rest];
  }
}

ImageProvider _routeCover(AppConfig config, RouteSummary route) {
  if (AppImages.isAssetPath(route.coverImageUrl)) {
    return AssetImage(route.coverImageUrl!);
  }
  final url = AppImages.resolveMediaUrl(config, route.coverImageUrl);
  if (url != null) {
    return NetworkImage(url);
  }
  return AssetImage(AppImages.routeFallbackAsset(route.slug));
}

/// Other routes of the region, shown right before the reviews.
class _SimilarRoutesSection extends ConsumerWidget {
  const _SimilarRoutesSection({required this.currentRouteId});

  static const double cardHeight = 172;
  static const double cardWidth = 214;
  static const double sectionHeight = 240;
  static const int maxItems = 6;

  final String currentRouteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(routesListProvider);
    final config = ref.watch(appConfigProvider);
    final routes = page.valueOrNull?.items
        .where((item) => item.id != currentRouteId)
        .take(maxItems)
        .toList(growable: false);

    if (routes != null && routes.isEmpty) {
      return const SizedBox.shrink();
    }

    final viewportWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: sectionHeight,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        minHeight: sectionHeight,
        maxHeight: sectionHeight,
        child: SizedBox(
          key: const ValueKey('similar-routes-full-bleed'),
          width: viewportWidth,
          height: sectionHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: _SectionDivider(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: _SectionTitle('Похожие маршруты:'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: cardHeight,
                child: routes == null
                    ? const _SimilarRoutesSkeleton()
                    : ListView.separated(
                        key: const ValueKey('similar-routes-list'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: routes.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return _SimilarRouteCard(
                            route: route,
                            image: _routeCover(config, route),
                            onTap: () => unawaited(
                              context.pushNamed(
                                AppRouteNames.routeDetails,
                                pathParameters: {'id': route.id},
                                extra: route,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimilarRoutesSkeleton extends StatelessWidget {
  const _SimilarRoutesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (context, _) => const SizedBox(width: 10),
      itemBuilder: (context, _) => Container(
        width: _SimilarRoutesSection.cardWidth,
        decoration: BoxDecoration(
          color: AppColors.controlSurface,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _SimilarRouteCard extends StatelessWidget {
  const _SimilarRouteCard({
    required this.route,
    required this.image,
    required this.onTap,
  });

  final RouteSummary route;
  final ImageProvider image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      formatDistanceKm(route.distanceMeters),
      transportLabel(route.transportMode),
      '${route.stopsCount} точек',
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Похожий маршрут: ${route.name}',
      child: SizedBox(
        width: _SimilarRoutesSection.cardWidth,
        child: Material(
          color: AppColors.controlSurface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'route-cover-${route.id}',
                  transitionOnUserGestures: true,
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) =>
                        const ColoredBox(color: AppColors.controlSurface),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                      stops: [0.38, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
  });

  final IconData? icon;
  final String? iconAsset;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: AppGlassCircle(
        dimension: 44,
        blur: 10,
        fillColor: Colors.black.withValues(alpha: 0.26),
        borderColor: Colors.white.withValues(alpha: 0.22),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: iconAsset != null
                  ? AppAssetIcon(iconAsset!, size: 22)
                  : Icon(icon, size: 22, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.name,
    required this.subtitle,
    required this.onMore,
  });

  final String name;
  final String subtitle;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage(AppImages.travelerPortrait),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: AppColors.secondaryInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Меню маршрута',
          child: SizedBox.square(
            dimension: 48,
            child: Material(
              color: AppColors.primaryInk,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onMore,
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primaryInk,
      ),
    );
  }
}

class _AudioGuideCard extends StatelessWidget {
  const _AudioGuideCard({
    required this.title,
    required this.author,
    required this.image,
    required this.onPlay,
  });

  final String title;
  final String author;
  final ImageProvider image;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: image,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.square(
                dimension: 44,
                child: ColoredBox(color: AppColors.controlSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '2ч 48м 17с',
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Слушать аудиогид',
            child: SizedBox.square(
              dimension: 44,
              child: Material(
                color: AppColors.elevatedSurface,
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFFE0E0E2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPlay,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTagsRow extends StatelessWidget {
  const _RouteTagsRow({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF646464),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteFacts extends StatelessWidget {
  const _RouteFacts({required this.route});

  final RouteDetail route;

  @override
  Widget build(BuildContext context) {
    final duration = route.estimatedDurationMinutes;
    final durationLabel = duration == null
        ? '—'
        : duration >= 60
        ? '${duration ~/ 60} ч ${duration % 60} мин'
        : '$duration мин';

    return Column(
      children: [
        _FactRow(
          icon: Icons.bolt_outlined,
          label: 'Сложность:',
          value: '${difficultyBolts(route.difficulty)}/5',
        ),
        _FactRow(
          icon: Icons.schedule_outlined,
          label: 'Время в пути:',
          value: durationLabel,
        ),
        _FactRow(
          icon: Icons.directions_car_outlined,
          label: 'Транспорт:',
          value: transportLabel(route.transportMode),
        ),
        _FactRow(
          icon: Icons.navigation_outlined,
          label: 'Расстояние:',
          value: formatDistanceKm(route.distanceMeters),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primaryInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: AppColors.secondaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.selected,
    required this.showDivider,
    required this.onNumberTap,
    required this.onOpen,
  });

  final RouteStop stop;
  final bool selected;
  final bool showDivider;
  final VoidCallback onNumberTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (stop.visitDurationMinutes != null) '${stop.visitDurationMinutes} мин',
      if (stop.note != null) stop.note!,
      if (stop.isOptional) 'опционально',
    ].join(' · ');

    return Column(
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F2F4) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Row(
            children: [
              Semantics(
                button: true,
                selected: selected,
                label: 'Показать остановку ${stop.position} на карте',
                child: GestureDetector(
                  onTap: onNumberTap,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.standard,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryInk,
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryInk.withValues(alpha: 0.25)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${stop.position}',
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _AdaptiveInlineIconButton(
                onPressed: onOpen,
                tooltip: 'Открыть место',
                icon: Icons.chevron_right_rounded,
                iconSize: 26,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F1)),
      ],
    );
  }
}

class _AdaptiveInlineIconButton extends StatelessWidget {
  const _AdaptiveInlineIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    this.iconSize = 24,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: iconSize,
      color: AppColors.primaryInk,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
    );
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return button;
    }
    return AppGlassCircle(
      dimension: 44,
      blur: 22,
      fillColor: Colors.white.withValues(alpha: 0.5),
      borderColor: Colors.white.withValues(alpha: 0.8),
      child: button,
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.topLabel});

  final String rating;
  final String topLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryInk,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
              const SizedBox(width: 6),
              Text(
                rating,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          topLabel,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
      ],
    );
  }
}

/// Placeholder review content from the Figma design; the reviews API is not
/// part of the current phase.
const _designReviews = [
  (
    author: 'Никита',
    subtitle: 'Продвинутый пешеход',
    stars: 4,
    score: '4,1',
    text:
        'По-моему скромному мнению, если смотреть через призму моего пешеходного '
        'опыта, маршрут не достаточно интересен с точки зрения сложности, не '
        'смотря на третий уровень. В остальном, новичкам понравится.',
  ),
  (
    author: 'Никита',
    subtitle: 'Продвинутый пешеход',
    stars: 4,
    score: '4,1',
    text:
        'По-моему скромному мнению, если смотреть через призму моего пешеходного '
        'опыта, маршрут не достаточно интересен с точки зрения сложности, не '
        'смотря на третий уровень.',
  ),
];

typedef _Review = ({
  String author,
  String subtitle,
  int stars,
  String score,
  String text,
});

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final _Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundImage: AssetImage(AppImages.travelerPortrait),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    Text(
                      review.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < 5; index++)
                Icon(
                  index < review.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: index < review.stars
                      ? AppColors.rating
                      : AppColors.secondaryInk,
                ),
              const SizedBox(width: 6),
              Text(
                review.score,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.primaryInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Читать отзыв полностью',
            style: AppTypography.button.copyWith(
              fontSize: 13,
              color: AppColors.primaryInk,
            ),
          ),
        ],
      ),
    );
  }
}
