import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/search/application/universal_search_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

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
                    onTap: () => unawaited(
                      context.pushNamed(
                        AppRouteNames.routeDetails,
                        pathParameters: {'id': route.id},
                        extra: route,
                      ),
                    ),
                  ),
                for (final profile in items.profiles)
                  DiscoveryProfileCard(
                    profile: profile,
                    onTap: () => unawaited(
                      context.pushNamed(
                        AppRouteNames.userProfile,
                        pathParameters: {'userId': profile.id},
                      ),
                    ),
                  ),
              ];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 304),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => children[index],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
      background: _mediaBackground(config, profile.coverUrl),
      hasImage: profile.coverUrl != null && profile.coverUrl!.isNotEmpty,
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
      subtitle: _rankLabel(profile.travelPoints),
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

class _DiscoveryCardShell extends StatelessWidget {
  const _DiscoveryCardShell({
    required this.height,
    required this.background,
    required this.hasImage,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double height;
  final Widget background;
  final bool hasImage;
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
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: leading,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.settingsRowTitle.copyWith(
                                color: foreground,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                color: secondary,
                                fontSize: 13,
                              ),
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
    );
  }
}

Widget _mediaBackground(AppConfig config, String? value) {
  if (value == null || value.isEmpty) {
    return const ColoredBox(color: AppColors.controlSurface);
  }
  return Image(
    image: _mediaProvider(config, value, fallback: AppImages.coastalBayHills),
    fit: BoxFit.cover,
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

String _rankLabel(int points) {
  if (points >= 10000) return 'Продвинутый пешеход';
  if (points >= 5000) return 'Исследователь';
  if (points >= 1000) return 'Путешественник';
  return 'Новичок';
}
