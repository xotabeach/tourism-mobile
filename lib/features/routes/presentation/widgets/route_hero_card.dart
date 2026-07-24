import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/routing/app_router.dart';

int difficultyBolts(String? difficulty) {
  return switch (difficulty) {
    'easy' => 2,
    'moderate' => 3,
    'hard' => 4,
    'expert' => 5,
    _ => 2,
  };
}

String difficultyLabel(String? difficulty) {
  return switch (difficulty) {
    'easy' => 'Лёгкий',
    'moderate' => 'Средний',
    'hard' => 'Сложный',
    'expert' => 'Экстрим',
    _ => 'Маршрут',
  };
}

String transportLabel(String? mode) {
  return switch (mode) {
    'walk' || 'foot' || 'hiking' => 'Пешком',
    'car' => 'На авто',
    'bike' => 'Вело',
    'public_transport' => 'Транспорт',
    _ => 'Маршрут',
  };
}

String formatDistanceKm(int? meters) {
  if (meters == null) {
    return '—';
  }
  final km = meters / 1000;
  final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return '$text км'.replaceAll('.', ',');
}

/// Large photo-style route card used on Home and Routes slider.
class RouteHeroCard extends ConsumerWidget {
  const RouteHeroCard({
    required this.route,
    this.height = 420,
    this.tags = const [],
    super.key,
  });

  final RouteSummary route;
  final double height;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final bolts = difficultyBolts(route.difficulty);
    final chipTags = tags.isNotEmpty
        ? tags
        : [
            difficultyLabel(route.difficulty),
            transportLabel(route.transportMode),
          ];
    final networkUrl = AppImages.resolveMediaUrl(config, route.coverImageUrl);
    final fallbackAsset = AppImages.routeFallbackAsset(route.slug);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => context.pushNamed(
          AppRouteNames.routeDetails,
          pathParameters: {'id': route.id},
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (networkUrl != null)
                  Image.network(
                    networkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Image.asset(fallbackAsset, fit: BoxFit.cover),
                  )
                else
                  Image.asset(fallbackAsset, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white,
                            backgroundImage: AssetImage(
                              AppImages.travelerPortrait,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route.authorLabel ?? 'Никита',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  transportLabel(route.transportMode),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Icon(
                                Icons.favorite_border,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chipTags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '4,${9 - (route.name.length % 3)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        route.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white, fontSize: 24),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              [
                                if (route.shortDescription != null)
                                  route.shortDescription!,
                                formatDistanceKm(route.distanceMeters),
                              ].join(' · '),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                            child: const SizedBox.square(
                              dimension: 54,
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.bolt,
                            size: 18,
                            color: i < bolts
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.25),
                          ),
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

class BuildRouteBanner extends StatelessWidget {
  const BuildRouteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.goNamed(AppRouteNames.routes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 226,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(AppImages.coastalBayHills, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.34),
                        Colors.black.withValues(alpha: 0.76),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            '> 250 маршрутов',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ПОСТРОЙ\nМАРШРУТ',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 30,
                                        height: 1.04,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Подбери маршрут для себя\nпо всем параметрам',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontSize: 15,
                                    height: 1.22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                            ),
                            child: const SizedBox.square(
                              dimension: 66,
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
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
