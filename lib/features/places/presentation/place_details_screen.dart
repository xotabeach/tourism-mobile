import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/places/application/places_providers.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});

  static const routePath = '/places/:id';

  /// Relative segment under the places branch (`/places/:id`).
  static const routeSegment = ':id';

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Карточка места')),
      body: placeAsync.when(
        data: (place) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                place.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (place.shortDescription != null) Text(place.shortDescription!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final category in place.categories)
                    Chip(label: Text(category.name)),
                  if (place.difficulty != null)
                    Chip(label: Text(place.difficulty!)),
                  if (place.isPaid) const Chip(label: Text('Платно')),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Координаты: ${place.lat.toStringAsFixed(4)}, '
                '${place.lng.toStringAsFixed(4)}',
              ),
              if (place.description != null) ...[
                const SizedBox(height: 16),
                Text(place.description!),
              ],
              if (place.safetyWarnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Предупреждения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final warning in place.safetyWarnings) Text('• $warning'),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
