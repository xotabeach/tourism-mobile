import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});

  static const routePath = '/places/:id';

  /// Relative segment under the places branch (`/places/:id`).
  static const routeSegment = ':id';

  final String placeId;

  /// Opens place details above the current route so back/edge-swipe return to
  /// route details instead of switching to the places catalog branch.
  static Future<T?> openFromRoute<T extends Object?>(
    BuildContext context, {
    required String routeId,
    required String placeId,
  }) {
    return context.push<T>('/routes/$routeId/place/$placeId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    return Scaffold(
      body: placeAsync.when(
        data: (place) {
          final heroAsset = AppImages.placeCoverAsset(place.slug);
          final isFavorite = ref.watch(
            favoritesProvider.select((s) => s.placeIds.contains(place.id)),
          );
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                foregroundColor: Colors.white,
                backgroundColor: AppColors.ink,
                automaticallyImplyLeading: false,
                leading: _AdaptivePlaceHeaderButton(
                  key: const ValueKey('place-details-back'),
                  semanticLabel: 'Назад',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => context.pop(),
                ),
                actions: [
                  _AdaptivePlaceHeaderButton(
                    semanticLabel: isFavorite
                        ? 'Удалить из избранного'
                        : 'Добавить в избранное',
                    onPressed: () async {
                      try {
                        await ref
                            .read(favoritesProvider.notifier)
                            .togglePlace(place.id);
                      } on Object {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось обновить избранное'),
                          ),
                        );
                      }
                    },
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  _AdaptivePlaceHeaderButton(
                    semanticLabel: 'Поделиться',
                    onPressed: () {},
                    icon: Icons.ios_share_rounded,
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(heroAsset, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.12),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final category in place.categories.take(2))
                                  _GlassPill(label: category.name),
                                if (place.isPaid)
                                  const _GlassPill(label: 'Платно'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              place.name,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (place.shortDescription != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                place.shortDescription!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.3,
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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  112 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            icon: Icons.terrain_rounded,
                            label: 'Сложность',
                            value: difficultyLabel(place.difficulty),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            icon: Icons.near_me_rounded,
                            label: 'Координаты',
                            value:
                                '${place.lat.toStringAsFixed(2)}, '
                                '${place.lng.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                    if (place.description != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Описание',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        place.description!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if (place.seasonality.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Сезон',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final season in place.seasonality)
                            Chip(label: Text(_seasonLabel(season))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Карта',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _MapPreview(
                      title: place.address ?? 'Точка на карте',
                      subtitle:
                          '${place.lat.toStringAsFixed(4)}, '
                          '${place.lng.toStringAsFixed(4)}',
                    ),
                    if (place.safetyWarnings.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Предупреждения',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      for (final warning in place.safetyWarnings)
                        _WarningRow(warning: warning),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppAsyncErrorView(
          onRetry: () => ref.invalidate(placeDetailProvider(placeId)),
        ),
      ),
    );
  }
}

class _AdaptivePlaceHeaderButton extends StatelessWidget {
  const _AdaptivePlaceHeaderButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    super.key,
  }) : assert((icon == null) != (iconAsset == null));

  final String semanticLabel;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final iconWidget = iconAsset == null
        ? Icon(icon, color: Colors.white, size: 22)
        : AppAssetIcon(iconAsset!, color: Colors.white, size: 22);
    final button = IconButton(
      tooltip: semanticLabel,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: iconWidget,
    );
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return button;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppGlassCircle(
        dimension: 44,
        blur: 24,
        fillColor: Colors.black.withValues(alpha: 0.28),
        borderColor: Colors.white.withValues(alpha: 0.48),
        child: button,
      ),
    );
  }
}

String _seasonLabel(String season) {
  return switch (season) {
    'spring' => 'Весна',
    'summer' => 'Лето',
    'autumn' => 'Осень',
    'winter' => 'Зима',
    _ => season,
  };
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.coastline),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.coastline,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: 156,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.place_rounded, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                          ),
                        ),
                      ],
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

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.warning});

  final String warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(warning)),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x + 42, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
