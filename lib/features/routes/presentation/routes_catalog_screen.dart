import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RoutesCatalogScreen extends ConsumerWidget {
  const RoutesCatalogScreen({super.key});

  static const routePath = '/routes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Маршруты Крыма')),
      body: routesAsync.when(
        data: (page) {
          if (page.items.isEmpty) {
            return const Center(child: Text('Маршруты не найдены'));
          }
          return ListView.separated(
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final route = page.items[index];
              final duration = route.estimatedDurationMinutes;
              final subtitleParts = <String>[
                if (route.shortDescription != null) route.shortDescription!,
                '${route.stopsCount} остановок',
                if (duration != null) '~${duration ~/ 60} ч',
              ];
              return ListTile(
                title: Text(route.name),
                subtitle: Text(subtitleParts.join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  AppRouteNames.routeDetails,
                  pathParameters: {'id': route.id},
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
