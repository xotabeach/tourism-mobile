import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_favorite_icon.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart'
    show difficultyLabel;
import 'package:tourism_mobile/routing/app_router.dart';

/// Photo-first place card, visually matching [RouteHeroCard]'s shape so
/// Home's Локации mode and the routes feed look consistent side by side.
class PlaceHeroCard extends ConsumerWidget {
  const PlaceHeroCard({
    required this.place,
    this.height = 304,
    this.interactive = true,
    super.key,
  });

  final PlaceSummary place;
  final double height;
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final card = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImages.coverImage(
                config: config,
                coverImageUrl: place.coverImageUrl,
                fallbackSeed: place.slug,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x45000000),
                      Color(0x00000000),
                      Color(0xBF000000),
                    ],
                    stops: [0, 0.36, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        _PlaceFavoriteButton(placeId: place.id),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final category in place.categories.take(2))
                          _PlaceTag(label: category.name),
                        if (place.difficulty != null)
                          _PlaceTag(label: difficultyLabel(place.difficulty)),
                        if (place.isPaid) const _PlaceTag(label: 'Платно'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.routeTitle.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    if (place.shortDescription?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        place.shortDescription!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.routeMetadata.copyWith(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!interactive) {
      return card;
    }

    return AppPressableScale(
      borderRadius: AppRadii.card,
      onTap: () => context.pushNamed(
        AppRouteNames.placeDetails,
        pathParameters: {'id': place.id},
      ),
      child: card,
    );
  }
}

class _PlaceTag extends StatelessWidget {
  const _PlaceTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppGlassPill(
      blur: 8,
      fillColor: Colors.black.withValues(alpha: 0.38),
      borderColor: Colors.white.withValues(alpha: 0.14),
      contentColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: Text(
        label,
        style: AppTypography.routeMetadata.copyWith(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PlaceFavoriteButton extends ConsumerWidget {
  const _PlaceFavoriteButton({required this.placeId});

  final String placeId;

  Future<void> _toggle(WidgetRef ref, BuildContext context) async {
    unawaited(AppHaptics.selectionClick());
    try {
      await ref.read(favoritesProvider.notifier).togglePlace(placeId);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить избранное')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      favoritesProvider.select((state) => state.placeIds.contains(placeId)),
    );
    return Semantics(
      key: ValueKey('favorite-toggle-$placeId'),
      button: true,
      toggled: selected,
      label: selected ? 'Удалить из избранного' : 'Добавить в избранное',
      child: AppGlassCircle(
        dimension: 44,
        blur: 10,
        fillColor: Colors.black.withValues(alpha: 0.42),
        borderColor: Colors.white.withValues(alpha: 0.16),
        contentColor: Colors.white,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_toggle(ref, context)),
          child: AppFavoriteIcon(selected: selected, size: 22),
        ),
      ),
    );
  }
}
