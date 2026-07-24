import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/theme/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

class RouteDetailsScreen extends ConsumerWidget {
  const RouteDetailsScreen({required this.routeId, super.key});

  static const routePath = '/routes/:id';

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(routeDetailProvider(routeId));

    return Scaffold(
      body: routeAsync.when(
        data: (route) {
          final config = ref.watch(appConfigProvider);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                foregroundColor: Colors.white,
                backgroundColor: AppColors.ink,
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const AppAssetIcon(
                      AppIconography.heart,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const AppAssetIcon(
                      AppIconography.download,
                      color: Colors.white,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImages.coverImage(
                        config: config,
                        coverImageUrl: route.coverImageUrl,
                        fallbackSeed: route.slug,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.78),
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
                            _AuthorLine(
                              label: route.authorLabel ?? 'КрымТрип редакция',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              route.name,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (route.shortDescription != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                route.shortDescription!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.86),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                sliver: SliverList.list(
                  children: [
                    _StatsGrid(route: route),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const AppAssetIcon(
                        AppIconography.play,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text('Пройти маршрут'),
                    ),
                    if (route.description != null) ...[
                      const SizedBox(height: 26),
                      Text(
                        'Описание',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route.description!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      'Карта и точки',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _RouteMapPreview(stops: route.stops),
                    const SizedBox(height: 22),
                    Text(
                      'Остановки',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...route.stops.map(_StopCard.new),
                    const SizedBox(height: 22),
                    Text(
                      'Похожие маршруты',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const _SimilarRoutesPlaceholder(),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage(AppImages.travelerPortrait),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        const Text(
          '4.9',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.route});

  final RouteDetail route;

  @override
  Widget build(BuildContext context) {
    final duration = route.estimatedDurationMinutes;
    final durationLabel = duration == null
        ? '—'
        : duration >= 60
        ? '${duration ~/ 60} ч ${duration % 60} мин'
        : '$duration мин';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _StatTile(
          icon: Icons.bolt_rounded,
          label: 'Сложность',
          value: difficultyLabel(route.difficulty),
        ),
        _StatTile(
          icon: Icons.route_rounded,
          label: 'Расстояние',
          value: formatDistanceKm(route.distanceMeters),
        ),
        _StatTile(
          icon: Icons.schedule_rounded,
          label: 'Время',
          value: durationLabel,
        ),
        _StatTile(
          icon: Icons.directions_car_rounded,
          label: 'Транспорт',
          value: transportLabel(route.transportMode),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

class _RouteMapPreview extends StatelessWidget {
  const _RouteMapPreview({required this.stops});

  final List<RouteStop> stops;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.coastline,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: 184,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _RouteLinePainter())),
            for (var i = 0; i < stops.length; i++)
              Positioned(
                left: 34.0 + i * 72,
                top: i.isEven ? 48 : 92,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Text(
                '${stops.length} точки маршрута',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard(this.stop);

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (stop.visitDurationMinutes != null) '${stop.visitDurationMinutes} мин',
      if (stop.note != null) stop.note!,
      if (stop.isOptional) 'опционально',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                child: Text('${stop.position}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimilarRoutesPlaceholder extends StatelessWidget {
  const _SimilarRoutesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Подбор похожих маршрутов появится вместе с Route Builder.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var y = 22.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 16), gridPaint);
    }

    final path = Path()
      ..moveTo(48, 65)
      ..cubicTo(
        size.width * 0.32,
        20,
        size.width * 0.48,
        150,
        size.width - 44,
        80,
      );
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.74)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
