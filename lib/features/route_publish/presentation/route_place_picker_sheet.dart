import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/publish_route_design_tokens.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';

Future<RouteLocation?> showRoutePlacePicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<RouteLocation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: PublishRouteDesignTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RoutePlacePickerSheet(title: title),
  );
}

class _RoutePlacePickerSheet extends ConsumerStatefulWidget {
  const _RoutePlacePickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_RoutePlacePickerSheet> createState() =>
      _RoutePlacePickerSheetState();
}

class _RoutePlacePickerSheetState
    extends ConsumerState<_RoutePlacePickerSheet> {
  final _controller = TextEditingController();
  var _query = '';
  var _mapMode = false;

  /// «Из избранного»: места, уже отмеченные сердечком, — обычно маршрут и
  /// собирают из них, а до этого их приходилось вспоминать по названию.
  var _favoritesOnly = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final result = _favoritesOnly
        ? ref
              .watch(placesListProvider)
              .whenData(
                (page) => PlaceListPage(
                  items: page.items
                      .where(
                        (place) =>
                            favorites.placeIds.contains(place.id) &&
                            (_query.isEmpty ||
                                place.name.toLowerCase().contains(
                                  _query.toLowerCase(),
                                )),
                      )
                      .toList(growable: false),
                  total: page.total,
                  limit: page.limit,
                  offset: page.offset,
                ),
              )
        : ref.watch(placesSearchProvider(_query));
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * .72 - bottom).clamp(
      320.0,
      screenHeight * .72,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 18 + bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: PublishRouteDesignTokens.rubik(
                fontSize: 20,
                weight: FontWeight.w600,
                color: PublishRouteDesignTokens.dark,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: PublishRouteDesignTokens.fieldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      style: PublishRouteDesignTokens.rubik(
                        fontSize: 15,
                        weight: FontWeight.w400,
                        color: PublishRouteDesignTokens.dark,
                      ),
                      cursorColor: PublishRouteDesignTokens.primaryBlue,
                      // Theme merges focusedOutline onto collapsed decorations;
                      // pin every border to none so the input itself is outline-free.
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Поиск по названию или адресу',
                        hintStyle: PublishRouteDesignTokens.rubik(
                          fontSize: 15,
                          weight: FontWeight.w400,
                          color: PublishRouteDesignTokens.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PickerToggle(
                  label: 'Из избранного',
                  icon: _favoritesOnly
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  selected: _favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                ),
                const Spacer(),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _mapMode = !_mapMode),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _mapMode ? 'Показать списком' : 'Выбрать на карте',
                    style: PublishRouteDesignTokens.rubik(
                      fontSize: 15,
                      weight: FontWeight.w500,
                      color: PublishRouteDesignTokens.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: result.when(
                loading: () => const Center(child: AppListSkeleton(rows: 4)),
                error: (_, _) => Center(
                  child: Text(
                    'Не удалось загрузить места. Повторите поиск.',
                    textAlign: TextAlign.center,
                    style: PublishRouteDesignTokens.rubik(
                      fontSize: 14,
                      weight: FontWeight.w400,
                      color: PublishRouteDesignTokens.mediumText,
                      height: 1.25,
                    ),
                  ),
                ),
                data: (page) => page.items.isEmpty && _favoritesOnly
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _query.isEmpty
                                ? 'В избранном пока нет мест — добавьте их '
                                      'сердечком в каталоге.'
                                : 'Среди избранных мест ничего не нашлось.',
                            textAlign: TextAlign.center,
                            style: PublishRouteDesignTokens.rubik(
                              fontSize: 14,
                              weight: FontWeight.w400,
                              color: PublishRouteDesignTokens.mediumText,
                              height: 1.25,
                            ),
                          ),
                        ),
                      )
                    : _mapMode
                    ? _PlacesMap(places: page.items, onSelected: _select)
                    : ListView.builder(
                        primary: false,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: page.items.length,
                        itemBuilder: (context, index) {
                          final place = page.items[index];
                          return Semantics(
                            button: true,
                            label: 'Выбрать место ${place.name}',
                            child: InkWell(
                              onTap: () => _select(place),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.place_outlined, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        place.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: PublishRouteDesignTokens.rubik(
                                          fontSize: 15,
                                          weight: FontWeight.w500,
                                          color: PublishRouteDesignTokens.dark,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(PlaceSummary place) {
    Navigator.of(context).pop(
      RouteLocation(
        id: place.id,
        name: place.name,
        subtitle: 'Крым',
        lat: place.lat,
        lng: place.lng,
      ),
    );
  }
}

class _PlacesMap extends StatelessWidget {
  const _PlacesMap({required this.places, required this.onSelected});

  final List<PlaceSummary> places;
  final ValueChanged<PlaceSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = places.take(8).toList();
    return Semantics(
      label: 'Карта выбора места',
      child: LayoutBuilder(
        builder: (context, constraints) => RouteMapPreview(
          height: constraints.maxHeight,
          selectedIndex: null,
          stops: [
            for (var index = 0; index < visible.length; index++)
              RouteStop(
                id: visible[index].id,
                position: index + 1,
                placeId: visible[index].id,
                placeName: visible[index].name,
                placeSlug: visible[index].slug,
                lat: visible[index].lat,
                lng: visible[index].lng,
              ),
          ],
          onPinTap: (index) => onSelected(visible[index]),
        ),
      ),
    );
  }
}

/// Небольшой переключатель над списком мест.
class _PickerToggle extends StatelessWidget {
  const _PickerToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? PublishRouteDesignTokens.primaryBlue.withValues(alpha: 0.1)
                : PublishRouteDesignTokens.fieldBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? PublishRouteDesignTokens.primaryBlue
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? PublishRouteDesignTokens.primaryBlue
                    : PublishRouteDesignTokens.mediumText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: PublishRouteDesignTokens.rubik(
                  fontSize: 13,
                  weight: FontWeight.w500,
                  color: selected
                      ? PublishRouteDesignTokens.primaryBlue
                      : PublishRouteDesignTokens.mediumText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
