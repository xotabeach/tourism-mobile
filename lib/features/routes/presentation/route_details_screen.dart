import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/routes/application/routes_providers.dart';

class RouteDetailsScreen extends ConsumerWidget {
  const RouteDetailsScreen({required this.routeId, super.key});

  static const routePath = '/routes/:id';

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(routeDetailProvider(routeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Карточка маршрута')),
      body: routeAsync.when(
        data: (route) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                route.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (route.shortDescription != null) Text(route.shortDescription!),
              if (route.description != null) ...[
                const SizedBox(height: 12),
                Text(route.description!),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (route.difficulty != null)
                    Chip(label: Text(route.difficulty!)),
                  if (route.transportMode != null)
                    Chip(label: Text(route.transportMode!)),
                  Chip(label: Text('${route.stopsCount} остановок')),
                  if (route.estimatedDurationMinutes != null)
                    Chip(label: Text('${route.estimatedDurationMinutes} мин')),
                ],
              ),
              const SizedBox(height: 24),
              Text('Остановки', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...route.stops.map((stop) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${stop.position}')),
                  title: Text(stop.placeName),
                  subtitle: Text(
                    [
                      if (stop.visitDurationMinutes != null)
                        '${stop.visitDurationMinutes} мин',
                      if (stop.note != null) stop.note!,
                      if (stop.isOptional) 'опционально',
                    ].join(' · '),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
