import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/audio_guide_card.dart';
import 'package:tourism_mobile/core/design/components/details_hero_loading_view.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/reviews/presentation/entity_reviews_section.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_collapsing_header.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_menu_bubble.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';
import 'package:tourism_mobile/routing/app_router.dart';

export 'package:tourism_mobile/features/reviews/presentation/entity_reviews_section.dart'
    show pendingReviewsNotYetPublished;

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

enum _RouteDetailsSection { about, comments }

class _RouteDetailsScreenState extends ConsumerState<RouteDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  // Anchors the route menu bubble to the "..." circle it unfolds from.
  final _menuAnchorKey = GlobalKey();
  late final AnimationController _galleryController;

  int? _selectedStop;
  var _selectedSection = _RouteDetailsSection.about;

  @override
  void initState() {
    super.initState();
    _galleryController = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
    );
    _scrollController.addListener(_onScrollCollapseGallery);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollCollapseGallery)
      ..dispose();
    _galleryController.dispose();
    super.dispose();
  }

  void _onScrollCollapseGallery() {
    if (_scrollController.offset > 24 && _galleryController.value > 0) {
      _settleGallery(0);
    }
  }

  void _toggleGallery() {
    if (_scrollController.hasClients && _scrollController.offset > 24) {
      return;
    }
    _settleGallery(_galleryController.value < 0.5 ? 1 : 0);
  }

  void _settleGallery(double target) {
    if (!mounted) {
      return;
    }
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

  void _openPlace(RouteStop stop) {
    unawaited(
      PlaceDetailsScreen.openFromRoute(
        context,
        routeId: widget.routeId,
        placeId: stop.placeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialRoute;
    final session = ref.watch(sessionProvider);
    final ownerPreview =
        initial != null &&
        initial.ownerUserId == session.userId &&
        (initial.publicationStatus != 'published' ||
            initial.visibility != 'public');
    final routeAsync = ownerPreview
        ? ref.watch(ownRouteDetailProvider(widget.routeId))
        : ref.watch(routeDetailProvider(widget.routeId));

    return Scaffold(
      backgroundColor: AppColors.elevatedSurface,
      body: routeAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        skipError: true,
        data: _buildContent,
        loading: () => widget.initialRoute == null
            ? DetailsHeroLoadingView(onBack: () => context.pop())
            : _buildInitialContent(widget.initialRoute!),
        error: (_, _) => AppAsyncErrorView(
          onRetry: () => ownerPreview
              ? ref.invalidate(ownRouteDetailProvider(widget.routeId))
              : ref.invalidate(routeDetailProvider(widget.routeId)),
        ),
      ),
    );
  }

  Widget _buildContent(RouteDetail route) {
    final config = ref.watch(appConfigProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isFavorite = ref.watch(
      favoritesProvider.select((s) => s.routeIds.contains(route.id)),
    );
    final authorName = route.authorLabel ?? 'КрымТрип редакция';
    final statusLabel = routeStatusLabel(route);
    final publiclyAvailable =
        route.publicationStatus == null ||
        (route.publicationStatus == 'published' &&
            (route.visibility == null || route.visibility == 'public'));

    VoidCallback? onAuthorTap;
    if (route.ownerUserId != null) {
      onAuthorTap = () {
        final ownerId = route.ownerUserId!;
        final session = ref.read(sessionProvider);
        if (session.userId == ownerId) {
          context.goNamed(AppRouteNames.profile);
        } else {
          unawaited(
            context.pushNamed(
              AppRouteNames.userProfile,
              pathParameters: {'userId': ownerId},
            ),
          );
        }
      };
    }

    return AnimatedBuilder(
      animation: _galleryController,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: RefreshIndicator(
          // Отзывы, избранное и статус публикации меняются, пока экран
          // открыт; тянем вниз — перечитываем маршрут целиком.
          onRefresh: () async {
            ref.invalidate(routeDetailProvider(widget.routeId));
            await ref.read(routeDetailProvider(widget.routeId).future);
          },
          child: CustomScrollView(
            key: const ValueKey('route-details-list'),
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              RouteCollapsingHeader(
                images: _galleryImages(config, route),
                title: route.name,
                isFavorite: isFavorite,
                expansionProgress: _galleryController.value,
                onToggleGallery: _toggleGallery,
                heroTag: 'route-cover-${route.id}',
                onBack: () => context.pop(),
                onToggleFavorite: () => unawaited(_toggleFavorite(route.id)),
                showFavorite: publiclyAvailable,
                onShare: () => unawaited(_shareRoute(route)),
                onDownload: () => unawaited(_toggleOffline(route)),
              ),
              // Lip lives in the header; body continues the sheet without
              // negative overlap (avoids author/photo z-fighting).
              SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.elevatedSurface,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 118 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AuthorRow(
                          name: authorName,
                          subtitle: authorSubtitle(route),
                          avatar: AppImages.avatarProvider(
                            config: config,
                            avatarUrl: route.authorAvatarUrl,
                          ),
                          isExpert: route.authorIsExpert,
                          onAuthorTap: onAuthorTap,
                          menuAnchorKey: _menuAnchorKey,
                          onMore: () => unawaited(_showRouteMenu(route)),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(height: 12),
                          _OwnerRouteStatusBanner(
                            label: statusLabel,
                            status: route.publicationStatus,
                          ),
                        ],
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
                        const SizedBox(height: 14),
                        _RouteDetailsTabs(
                          selected: _selectedSection,
                          onSelected: (section) {
                            if (_selectedSection == section) {
                              return;
                            }
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _selectedSection = section);
                          },
                        ),
                        const _SectionDivider(),
                        if (_selectedSection == _RouteDetailsSection.about) ...[
                          AudioGuideCard(
                            title: route.name,
                            author: authorName,
                            image: _routeCover(config, route),
                            onPlay: () => _showSoon('Аудиогид'),
                          ),
                          const SizedBox(height: 16),
                          _RouteTagsRow(tags: routeTagLabels(route)),
                          const SizedBox(height: 16),
                          _RouteFacts(route: route),
                          if (route.routing != null &&
                              route.routing!.qualityStatus != 'unknown') ...[
                            const SizedBox(height: 12),
                            _RouteQualityNotice(routing: route.routing!),
                          ],
                          const _SectionDivider(),
                          const _SectionTitle('Карта маршрута:'),
                          const SizedBox(height: 14),
                          RouteStaticMap(
                            staticMapUrl: route.staticMapUrl,
                            stops: route.stops,
                            geometry: route.geometry,
                            config: config,
                            footerLabel: routePointsLabel(route.stops.length),
                            selectedIndex: _selectedStop,
                            onStopTap: _selectStop,
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle('Остановки:'),
                          const SizedBox(height: 6),
                          for (
                            var index = 0;
                            index < route.stops.length;
                            index++
                          )
                            _StopRow(
                              stop: route.stops[index],
                              selected: _selectedStop == index,
                              showDivider: index != route.stops.length - 1,
                              onNumberTap: () => _selectStop(index),
                              onOpen: () => _openPlace(route.stops[index]),
                            ),
                          _ArticlesForRouteSection(routeId: route.id),
                          _SimilarRoutesSection(currentRouteId: route.id),
                        ] else ...[
                          EntityReviewsSection(
                            entityId: route.id,
                            kind: ReviewEntityKind.route,
                            allowComposer: publiclyAvailable,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialContent(RouteSummary route) {
    final config = ref.watch(appConfigProvider);
    return ColoredBox(
      color: AppColors.elevatedSurface,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          RouteCollapsingHeader(
            images: [_routeCover(config, route)],
            title: route.name,
            isFavorite: false,
            heroTag: 'route-cover-${route.id}',
            onBack: () => context.pop(),
            onToggleFavorite: () {},
            showFavorite:
                route.publicationStatus == null ||
                (route.publicationStatus == 'published' &&
                    (route.visibility == null || route.visibility == 'public')),
            onShare: () {},
            onDownload: () {},
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DetailsHeroBodySkeleton(),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String routeId) async {
    try {
      await ref.read(favoritesProvider.notifier).toggleRoute(routeId);
    } on Object {
      if (!mounted) return;
      showAppNotice(context, 'Не удалось обновить избранное');
    }
  }

  Future<void> _toggleOffline(RouteDetail route) async {
    try {
      final store = ref.read(offlineRouteStoreProvider);
      final existing = await store.get(route.id);
      if (existing != null) {
        await removeDownloadedRoute(ref, route.id);
        if (mounted) {
          _showMessage('Маршрут удалён из офлайн');
        }
        return;
      }

      await downloadRouteSnapshot(ref, route);
      if (mounted) {
        _showMessage('Маршрут сохранён для офлайн-доступа');
      }
    } on Object {
      if (mounted) {
        _showMessage('Не удалось сохранить маршрут офлайн');
      }
    }
  }

  void _showMessage(String message) {
    showAppNotice(context, message);
  }

  void _showSoon(String feature) {
    _showMessage('$feature появится позже');
  }

  String _shareText(RouteDetail route) {
    final author = route.authorLabel ?? 'КрымТрип редакция';
    final description = route.description?.trim();
    return [
      route.name,
      'Автор: $author',
      if (description != null && description.isNotEmpty) description,
      if (route.stops.isNotEmpty)
        'Точки: ${route.stops.map((stop) => stop.placeName).join(' → ')}',
    ].join('\n\n');
  }

  Future<void> _shareRoute(RouteDetail route) async {
    await SharePlus.instance.share(ShareParams(text: _shareText(route)));
  }

  Future<void> _copyRouteText(RouteDetail route) async {
    await Clipboard.setData(ClipboardData(text: _shareText(route)));
    if (mounted) {
      _showMessage('Текст маршрута скопирован');
    }
  }

  void _reportRoute(RouteDetail route) {
    unawaited(
      context.pushNamed(
        AppRouteNames.settingsReportRoute,
        extra: {'routeId': route.id, 'routeName': route.name},
      ),
    );
  }

  Future<void> _editOwnRoute(RouteDetail route) async {
    final drafts = ref.read(routeDraftRepositoryProvider);
    final local = await drafts.load();
    if (!mounted) return;
    if (local?.serverId == route.id) {
      _openPublishScreen();
      return;
    }
    // Черновик лежит локально, поэтому на другом телефоне его нет. Тянем
    // маршрут с сервера и кладём в то же локальное хранилище, из которого
    // читает редактор — правка перестаёт быть привязанной к устройству
    // (жалоба 2026-09-04).
    if (local != null && local.hasMeaningfulContent) {
      final replace = await _confirmReplaceLocalDraft(local);
      if (replace != true || !mounted) return;
    }
    try {
      final remote = await ref
          .read(routePublicationRepositoryProvider)
          .loadForEdit(route.id);
      await drafts.save(remote);
      if (!mounted) return;
      _openPublishScreen();
    } on AppFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('Не удалось открыть маршрут для правки');
    }
  }

  void _openPublishScreen() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoutePublishScreen()),
      ),
    );
  }

  /// Загрузка чужого маршрута затрёт незавершённый черновик — спрашиваем.
  Future<bool?> _confirmReplaceLocalDraft(RouteDraft local) {
    final title = local.title.trim();
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Заменить черновик?'),
        content: Text(
          title.isEmpty
              ? 'На этом устройстве есть незаконченный черновик. Он будет '
                    'заменён этим маршрутом.'
              : 'На этом устройстве есть незаконченный черновик «$title». '
                    'Он будет заменён этим маршрутом.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawOwnRoute(RouteDetail route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Снять с публикации?'),
        content: const Text(
          'Маршрут будет скрыт из каталога и его нужно будет отправить на '
          'проверку заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Снять с публикации'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(routePublicationRepositoryProvider).withdraw(route.id);
      ref.invalidate(ownRouteDetailProvider(route.id));
      if (!mounted) return;
      _showMessage('Маршрут снят с публикации');
      await _editOwnRoute(route);
    } on Object {
      if (mounted) {
        _showMessage('Не удалось снять маршрут с публикации');
      }
    }
  }

  Future<void> _showRouteMenu(RouteDetail route) async {
    final session = ref.read(sessionProvider);
    final isOwner = route.ownerUserId == session.userId;
    final store = ref.read(offlineRouteStoreProvider);
    final downloaded = await store.get(route.id) != null;
    if (!mounted) return;
    await showRouteMenuBubble(
      context: context,
      anchorKey: _menuAnchorKey,
      actions: [
        RouteMenuAction(
          icon: downloaded
              ? Icons.download_done_rounded
              : Icons.download_rounded,
          label: downloaded ? 'Удалить из офлайн' : 'Скачать офлайн',
          onSelected: () => unawaited(_toggleOffline(route)),
        ),
        RouteMenuAction(
          icon: Icons.ios_share_rounded,
          label: 'Поделиться',
          onSelected: () => unawaited(_shareRoute(route)),
        ),
        RouteMenuAction(
          icon: Icons.copy_rounded,
          label: 'Скопировать текст',
          onSelected: () => unawaited(_copyRouteText(route)),
        ),
        RouteMenuAction(
          icon: Icons.flag_outlined,
          label: 'Пожаловаться на маршрут',
          onSelected: () => _reportRoute(route),
        ),
        // Править можно и опубликованный маршрут: сохранение вернёт его на
        // проверку, как и у статей.
        if (isOwner && route.publicationStatus != 'archived')
          RouteMenuAction(
            icon: Icons.edit_outlined,
            label: 'Редактировать',
            onSelected: () => unawaited(_editOwnRoute(route)),
          ),
        if (isOwner &&
            (route.publicationStatus == 'pending_review' ||
                route.publicationStatus == 'published'))
          RouteMenuAction(
            icon: Icons.visibility_off_outlined,
            label: 'Снять с публикации',
            onSelected: () => unawaited(_withdrawOwnRoute(route)),
          ),
      ],
    );
  }

  List<ImageProvider> _galleryImages(AppConfig config, RouteDetail route) {
    final uploadedImages = route.media
        .where((item) => item.isImage)
        .map((item) => _routeMediaImageProvider(config, item.url))
        .whereType<ImageProvider>()
        .toList(growable: false);
    if (uploadedImages.isNotEmpty) {
      return uploadedImages;
    }
    return [_routeCover(config, route)];
  }
}

class _RouteDetailsTabs extends StatelessWidget {
  const _RouteDetailsTabs({required this.selected, required this.onSelected});

  final _RouteDetailsSection selected;
  final ValueChanged<_RouteDetailsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: _RouteDetailsTab(
              key: const ValueKey('route-about-tab'),
              label: 'О маршруте',
              selected: selected == _RouteDetailsSection.about,
              onTap: () => onSelected(_RouteDetailsSection.about),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RouteDetailsTab(
              key: const ValueKey('route-comments-tab'),
              label: 'Комментарии',
              selected: selected == _RouteDetailsSection.comments,
              onTap: () => onSelected(_RouteDetailsSection.comments),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailsTab extends StatelessWidget {
  const _RouteDetailsTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accentBlue : AppColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: selected ? AppColors.accentBlue : const Color(0xFFE2E2E2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.1,
                color: selected ? Colors.white : AppColors.primaryInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerRouteStatusBanner extends StatelessWidget {
  const _OwnerRouteStatusBanner({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (icon, description) = switch (status) {
      'pending_review' => (
        Icons.schedule_rounded,
        'Маршрут проверяет команда модерации. Пока он виден только вам.',
      ),
      'rejected' => (
        Icons.info_outline_rounded,
        'Перед публикацией маршруту нужны исправления.',
      ),
      'draft' => (
        Icons.edit_note_rounded,
        'Это сохранённый черновик, доступный только вам.',
      ),
      _ => (
        Icons.visibility_off_outlined,
        'Маршрут скрыт от других путешественников.',
      ),
    };
    return Semantics(
      label: 'Статус маршрута: $label. $description',
      child: Container(
        key: const ValueKey('route-owner-status'),
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.chip.copyWith(
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: AppTypography.routeMetadata.copyWith(
                      color: AppColors.secondaryInk,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ImageProvider? _routeMediaImageProvider(AppConfig config, String value) {
  if (AppImages.isAssetPath(value)) {
    return AssetImage(value);
  }
  final resolved = AppImages.resolveMediaUrl(config, value);
  return resolved == null
      ? null
      : AppImages.imageProvider(resolvedUrl: resolved);
}

ImageProvider _routeCover(AppConfig config, RouteSummary route) {
  if (AppImages.isAssetPath(route.coverImageUrl)) {
    return AssetImage(route.coverImageUrl!);
  }
  final url = AppImages.resolveMediaUrl(config, route.coverImageUrl);
  if (url != null) {
    return AppImages.imageProvider(
      resolvedUrl: url,
      assetFallback: AppImages.routeFallbackAsset(route.slug),
    );
  }
  return AssetImage(AppImages.routeFallbackAsset(route.slug));
}

/// "Статьи об этом маршруте" — only rendered once there's at least one
/// published article, per the mobile backlog (G.8 entry points).
class _ArticlesForRouteSection extends ConsumerWidget {
  const _ArticlesForRouteSection({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(articlesForRouteProvider(routeId));
    final articles = page.valueOrNull?.items;
    if (articles == null || articles.isEmpty) {
      return const SizedBox.shrink();
    }
    final viewportWidth = MediaQuery.sizeOf(context).width;
    const sectionHeight = 254.0;
    return SizedBox(
      height: sectionHeight,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        minHeight: sectionHeight,
        maxHeight: sectionHeight,
        child: SizedBox(
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
                child: _SectionTitle('Статьи об этом маршруте:'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 320,
                child: ListView.separated(
                  key: const ValueKey('route-articles-list'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: articles.length,
                  separatorBuilder: (context, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => ArticleCard(
                    article: articles[index],
                    width: 290,
                    height: 320,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Other routes of the region, shown right before the reviews.
class _SimilarRoutesSection extends ConsumerWidget {
  const _SimilarRoutesSection({required this.currentRouteId});

  // Compact version of the shared 361×304 route-card proportion.
  static const double cardHeight = 210;
  static const double cardWidth = 250;
  static const double sectionHeight = 278;
  static const int maxItems = 6;

  final String currentRouteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(routesListProvider);
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
                          return SizedBox(
                            width: cardWidth,
                            child: RouteHeroCard(
                              route: route,
                              height: cardHeight,
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
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.isExpert,
    required this.onMore,
    required this.menuAnchorKey,
    this.onAuthorTap,
  });

  final String name;
  final String subtitle;
  final ImageProvider avatar;
  final bool isExpert;
  final VoidCallback onMore;
  final GlobalKey menuAnchorKey;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: AppExpertFrame(
                    isExpert: isExpert,
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(backgroundImage: avatar),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
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
                          ),
                          if (isExpert) ...[
                            const SizedBox(width: 7),
                            const AppExpertBadge(compact: true),
                          ],
                        ],
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
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Меню маршрута',
          child: SizedBox.square(
            key: menuAnchorKey,
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
    final routing = route.routing;
    final totalSeconds = routing?.totalDurationSeconds;
    final durationLabel = totalSeconds != null
        ? _formatDurationSeconds(totalSeconds)
        : _formatDurationMinutes(route.estimatedDurationMinutes);

    return Column(
      children: [
        _FactRow(
          icon: Icons.bolt_outlined,
          label: 'Сложность:',
          value: '${difficultyBolts(route.difficulty)}/5',
        ),
        if (routing?.movementDurationSeconds case final seconds?)
          _FactRow(
            icon: Icons.directions_walk_rounded,
            label: 'В дороге:',
            value: _formatDurationSeconds(seconds),
          ),
        if (routing?.visitDurationMinutes case final minutes?)
          _FactRow(
            icon: Icons.place_outlined,
            label: 'На остановках:',
            value: _formatDurationMinutes(minutes),
          ),
        _FactRow(
          icon: Icons.schedule_outlined,
          label: routing == null ? 'Время маршрута:' : 'Всего:',
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
        if (routing?.elevationGainMeters case final gain?)
          _FactRow(
            icon: Icons.terrain_outlined,
            label: 'Набор высоты:',
            value: '$gain м',
          ),
      ],
    );
  }

  static String _formatDurationMinutes(int? minutes) {
    if (minutes == null) {
      return '—';
    }
    return _formatDurationSeconds(minutes * 60);
  }

  static String _formatDurationSeconds(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) {
      return '$minutes мин';
    }
    final remainder = minutes % 60;
    return remainder == 0
        ? '${minutes ~/ 60} ч'
        : '${minutes ~/ 60} ч $remainder мин';
  }
}

class _RouteQualityNotice extends StatelessWidget {
  const _RouteQualityNotice({required this.routing});

  final RouteRoutingInfo routing;

  @override
  Widget build(BuildContext context) {
    final needsAttention =
        routing.qualityStatus == 'needs_review' ||
        routing.qualityStatus == 'unusable';
    final background = needsAttention
        ? const Color(0xFFFFF3E4)
        : routing.synthetic || routing.qualityStatus == 'unverified'
        ? const Color(0xFFF1F1F3)
        : const Color(0xFFEAF2FF);
    final foreground = needsAttention
        ? const Color(0xFF875000)
        : routing.synthetic || routing.qualityStatus == 'unverified'
        ? AppColors.secondaryInk
        : AppColors.accentBlue;
    final details = _warningLabels(routing.warnings);
    final title = switch (routing.qualityStatus) {
      'verified' => 'Маршрут проверен',
      'verified_with_warnings' => 'Путь построен по дорогам и тропам',
      'needs_review' => 'Есть участок для дополнительной проверки',
      'unusable' => 'Маршрут пока нельзя проходить',
      _ => 'Маршрут пока ориентировочный',
    };
    final body = details.isNotEmpty
        ? details.join(' ')
        : switch (routing.qualityStatus) {
            'verified' => 'Геометрия и ограничения подтверждены.',
            'verified_with_warnings' =>
              'Перед поездкой проверьте доступность и сезонные ограничения.',
            'needs_review' =>
              'Проверьте предупреждения перед началом прохождения.',
            'unusable' => 'Выберите другой маршрут или режим движения.',
            _ => 'Расстояние и линия могут быть приблизительными.',
          };

    return Semantics(
      label: '$title. $body',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                needsAttention
                    ? Icons.warning_amber_rounded
                    : Icons.route_rounded,
                size: 21,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.button.copyWith(
                        color: AppColors.primaryInk,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTypography.greetingSubtitle.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _warningLabels(List<String> warnings) {
    final labels = <String>[];
    void add(String value) {
      if (!labels.contains(value) && labels.length < 2) {
        labels.add(value);
      }
    }

    for (final warning in warnings) {
      switch (warning) {
        case 'slope_above_requested_pace':
          add('Уклон выше выбранного темпа.');
        case 'elevation_gain_above_requested_pace':
          add('Набор высоты может оказаться слишком большим.');
        case 'dirt_road_surface_requires_review':
          add('Есть участок по грунтовой дороге.');
        case 'ferry_schedule_and_access_unknown':
          add('Есть паромный участок — проверьте расписание.');
        case 'stairs_require_review':
          add('На пути могут быть лестницы.');
        case 'elevation_gain_unknown' || 'slope_unknown':
          add('Высотный профиль ещё уточняется.');
      }
    }
    return labels;
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
