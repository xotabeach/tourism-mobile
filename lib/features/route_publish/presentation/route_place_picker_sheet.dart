import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(placesSearchProvider(_query));
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * .72 - bottom).clamp(
      320.0,
      screenHeight * .72,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottom),
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
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: PublishRouteDesignTokens.fieldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PublishRouteDesignTokens.border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value.trim()),
                style: PublishRouteDesignTokens.rubik(
                  fontSize: 15,
                  weight: FontWeight.w400,
                  color: PublishRouteDesignTokens.dark,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Поиск по названию или адресу',
                  hintStyle: PublishRouteDesignTokens.rubik(
                    fontSize: 15,
                    weight: FontWeight.w400,
                    color: PublishRouteDesignTokens.secondaryText,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
                data: (page) => _mapMode
                    ? _PlacesMap(places: page.items, onSelected: _select)
                    : ListView.builder(
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
