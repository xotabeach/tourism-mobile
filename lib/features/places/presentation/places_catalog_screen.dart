import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class PlacesCatalogScreen extends ConsumerWidget {
  const PlacesCatalogScreen({super.key});

  static const routePath = '/places';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Места Крыма')),
      body: placesAsync.when(
        data: (page) {
          if (page.items.isEmpty) {
            return const Center(child: Text('Места не найдены'));
          }
          return ListView.separated(
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final place = page.items[index];
              return ListTile(
                title: Text(place.name),
                subtitle: Text(
                  place.shortDescription ??
                      place.categories.map((c) => c.name).join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  AppRouteNames.placeDetails,
                  pathParameters: {'id': place.id},
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
