import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_expert_style.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/search/application/universal_search_provider.dart';

class UniversalSearchPanel extends ConsumerWidget {
  const UniversalSearchPanel({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = query.trim();
    if (normalized.runes.length < 2) {
      return const SizedBox.shrink();
    }
    final result = ref.watch(universalSearchProvider(normalized));
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            border: Border.all(color: AppColors.hairline),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: result.when(
            loading: () => const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const SizedBox(
              height: 72,
              child: Center(child: Text('Не удалось выполнить поиск')),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SizedBox(
                  height: 72,
                  child: Center(child: Text('Ничего не найдено')),
                );
              }
              final children = <Widget>[
                for (final route in items.routes)
                  DiscoveryRouteCard(
                    route: route,
                    onTap: () => _openResult(
                      context,
                      '/routes/${route.id}',
                      extra: route,
                    ),
                  ),
                for (final profile in items.profiles)
                  DiscoveryProfileCard(
                    profile: profile,
                    onTap: () =>
                        _openResult(context, '/profile/users/${profile.id}'),
                  ),
                for (final place in items.places)
                  DiscoveryPlaceCard(
                    place: place,
                    onTap: () => _openResult(context, '/places/${place.id}'),
                  ),
              ];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 304),
                child: NotificationListener<ScrollNotification>(
                  // Keep parent home ListView from stealing vertical drags.
                  onNotification: (_) => true,
                  child: ListView.separated(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: children.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => children[index],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void _openResult(BuildContext context, String location, {Object? extra}) {
  // Navigate first — unfocusing before push used to dispose this panel and
  // cancel the route change when results were focus-gated on Home. Clear on
  // the next frame so the leaving screen resets without aborting navigation.
  final navigator = GoRouter.of(context);
  unawaited(navigator.push(location, extra: extra));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

class DiscoveryProfileCard extends ConsumerWidget {
  const DiscoveryProfileCard({
    required this.profile,
    required this.onTap,
    this.height = 88,
    super.key,
  });

  final PublicUserProfile profile;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return _DiscoveryCardShell(
      height: height,
      background: _profileCoverBackground(config, profile),
      hasImage: true,
      isExpert: profile.isExpert,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.controlSurface,
        backgroundImage: _mediaProvider(
          config,
          profile.avatarUrl,
          fallback: AppImages.travelerPortrait,
        ),
      ),
      title: profile.displayName,
      subtitle: profile.rankTitle,
    );
  }
}

class DiscoveryRouteCard extends ConsumerWidget {
  const DiscoveryRouteCard({
    required this.route,
    required this.onTap,
    this.height = 88,
    super.key,
  });

  final RouteSummary route;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return _DiscoveryCardShell(
      height: height,
      background: _mediaBackground(config, route.coverImageUrl),
      hasImage: route.coverImageUrl != null && route.coverImageUrl!.isNotEmpty,
      isExpert: route.authorIsExpert,
      onTap: onTap,
      leading: const CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.controlSurface,
        child: Icon(Icons.route_rounded, color: AppColors.accentBlue),
      ),
      title: route.name,
      subtitle: route.authorLabel ?? 'Маршрут Крыма',
    );
  }
}

class DiscoveryPlaceCard extends StatelessWidget {
  const DiscoveryPlaceCard({
    required this.place,
    required this.onTap,
    this.height = 88,
    super.key,
  });

  final PlaceSummary place;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final category = place.categories.isEmpty
        ? 'Достопримечательность'
        : place.categories.first.name;
    return _DiscoveryCardShell(
      height: height,
      background: const ColoredBox(color: AppColors.controlSurface),
      hasImage: false,
      isExpert: false,
      onTap: onTap,
      leading: const CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.elevatedSurface,
        child: Icon(Icons.place_outlined, color: AppColors.accentBlue),
      ),
      title: place.name,
      subtitle: category,
    );
  }
}

class _DiscoveryCardShell extends StatelessWidget {
  const _DiscoveryCardShell({
    required this.height,
    required this.background,
    required this.hasImage,
    required this.isExpert,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double height;
  final Widget background;
  final bool hasImage;
  final bool isExpert;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = hasImage ? Colors.white : AppColors.primaryInk;
    final secondary = hasImage
        ? Colors.white.withValues(alpha: 0.84)
        : AppColors.secondaryInk;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: AppExpertFrame(
        isExpert: isExpert,
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  background,
                  if (hasImage)
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x52000000)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        AppExpertFrame(
                          isExpert: isExpert,
                          borderRadius: BorderRadius.circular(999),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isExpert
                                  ? null
                                  : Border.all(color: Colors.white, width: 1.2),
                            ),
                            child: leading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.settingsRowTitle
                                          .copyWith(
                                            color: foreground,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
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
                                style: AppTypography.settingsRowSubtitle
                                    .copyWith(color: secondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: hasImage
                                ? Colors.white.withValues(alpha: 0.32)
                                : AppColors.controlSurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasImage
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.hairline,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: foreground,
                            size: 27,
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
      ),
    );
  }
}

Widget _profileCoverBackground(AppConfig config, PublicUserProfile profile) {
  final fallback = AppImages.routeFallbackAsset(profile.id);
  if (profile.coverUrl == null || profile.coverUrl!.isEmpty) {
    return Image.asset(fallback, fit: BoxFit.cover);
  }
  return Image(
    image: _mediaProvider(config, profile.coverUrl, fallback: fallback),
    fit: BoxFit.cover,
  );
}

Widget _mediaBackground(AppConfig config, String? value) {
  return AppImages.coverImage(
    config: config,
    coverImageUrl: value,
    fallbackSeed: value ?? '',
  );
}

ImageProvider _mediaProvider(
  AppConfig config,
  String? value, {
  required String fallback,
}) {
  if (AppImages.isAssetPath(value)) return AssetImage(value!);
  return AppImages.imageProvider(
    resolvedUrl: AppImages.resolveMediaUrl(config, value),
    assetFallback: fallback,
  );
}
