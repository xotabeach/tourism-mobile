import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';

enum AttachKind { route, place }

class ArticleAttachment {
  const ArticleAttachment({
    required this.kind,
    required this.id,
    required this.name,
  });

  final AttachKind kind;
  final String id;
  final String name;
}

/// Picks the one route *or* place an article is about.
///
/// The existing `showRoutePlacePicker` cannot be reused: it is places-only
/// and returns a `RouteLocation` with coordinates, which an article has no
/// use for. Both halves here search the ordinary catalog endpoints, which
/// already accept a free-text query.
Future<ArticleAttachment?> showArticleAttachPicker(
  BuildContext context, {
  AttachKind initialKind = AttachKind.route,
}) {
  return showModalBottomSheet<ArticleAttachment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AttachPickerSheet(initialKind: initialKind),
  );
}

class _AttachPickerSheet extends ConsumerStatefulWidget {
  const _AttachPickerSheet({required this.initialKind});

  final AttachKind initialKind;

  @override
  ConsumerState<_AttachPickerSheet> createState() => _AttachPickerSheetState();
}

class _AttachPickerSheetState extends ConsumerState<_AttachPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  late var _kind = widget.initialKind;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _query = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'О чём статья',
              style: AppTypography.sectionTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),
            AppSegmentedToggle(
              labels: const ['Маршрут', 'Место'],
              selected: _kind == AttachKind.route ? 'Маршрут' : 'Место',
              onSelected: (label) => setState(() {
                _kind = label == 'Маршрут'
                    ? AttachKind.route
                    : AttachKind.place;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: _kind == AttachKind.route
                    ? 'Найти маршрут'
                    : 'Найти место',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  borderSide: const BorderSide(color: Color(0xFFD9D9DB)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _kind == AttachKind.route
                  ? _RouteResults(query: _query)
                  : _PlaceResults(query: _query),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteResults extends ConsumerWidget {
  const _RouteResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesSearchProvider(query));
    return routesAsync.when(
      loading: () => const AppListSkeleton(rows: 4),
      error: (_, _) => const _ResultsMessage('Не удалось загрузить маршруты'),
      data: (page) {
        if (page.items.isEmpty) {
          return const _ResultsMessage('Ничего не нашлось');
        }
        return ListView.separated(
          itemCount: page.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final route = page.items[index];
            return ListTile(
              leading: const Icon(Icons.route_rounded),
              title: Text(route.name),
              subtitle: route.shortDescription == null
                  ? null
                  : Text(
                      route.shortDescription!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.of(context).pop(
                ArticleAttachment(
                  kind: AttachKind.route,
                  id: route.id,
                  name: route.name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaceResults extends ConsumerWidget {
  const _PlaceResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placesSearchProvider(query));
    return placesAsync.when(
      loading: () => const AppListSkeleton(rows: 4),
      error: (_, _) => const _ResultsMessage('Не удалось загрузить места'),
      data: (page) {
        if (page.items.isEmpty) {
          return const _ResultsMessage('Ничего не нашлось');
        }
        return ListView.separated(
          itemCount: page.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final place = page.items[index];
            return ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(place.name),
              subtitle: place.shortDescription == null
                  ? null
                  : Text(
                      place.shortDescription!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.of(context).pop(
                ArticleAttachment(
                  kind: AttachKind.place,
                  id: place.id,
                  name: place.name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ResultsMessage extends StatelessWidget {
  const _ResultsMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: AppTypography.routeMetadata.copyWith(
          color: AppColors.secondaryInk,
        ),
      ),
    );
  }
}
