import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';

/// Real 2GIS map raster with the app's own tappable stops drawn on top.
///
/// The backend renders only the basemap and the route line and is told the
/// exact center/zoom, so the same Web Mercator math places our pins on the
/// image — the provider's own numbered markers are suppressed to avoid two
/// competing sets of points. Falls back to the stylized [RouteMapPreview]
/// when there is no usable raster (no key, offline, missing coordinates).
class RouteStaticMap extends StatefulWidget {
  const RouteStaticMap({
    required this.staticMapUrl,
    required this.stops,
    required this.config,
    this.geometry,
    this.height = 260,
    this.footerLabel,
    this.interactive = true,
    this.selectedIndex,
    this.onStopTap,
    super.key,
  });

  /// Backend preview endpoint for this route, or null when the server does
  /// not offer one — then the stylized fallback is used instead of a raster.
  final String? staticMapUrl;
  final List<RouteStop> stops;
  final AppConfig config;
  final RouteGeometry? geometry;
  final double height;
  final String? footerLabel;

  /// Whether tapping opens the zoomable full-screen map.
  final bool interactive;

  /// Index into [stops] of the highlighted stop. When [onStopTap] is given the
  /// selection is owned by the parent, so tapping a pin also highlights the
  /// matching row in the stop list (and vice versa).
  final int? selectedIndex;
  final ValueChanged<int>? onStopTap;

  @override
  State<RouteStaticMap> createState() => _RouteStaticMapState();
}

class _RouteStaticMapState extends State<RouteStaticMap> {
  int? _uncontrolledSelected;
  var _imageFailed = false;

  /// Selected index within [RouteStaticMap.stops], parent-owned when the
  /// screen passes [RouteStaticMap.onStopTap].
  int? get _selectedStopIndex =>
      widget.onStopTap != null ? widget.selectedIndex : _uncontrolledSelected;

  void _selectStop(int stopIndex) {
    final onStopTap = widget.onStopTap;
    if (onStopTap != null) {
      onStopTap(stopIndex);
      return;
    }
    setState(() {
      _uncontrolledSelected =
          _uncontrolledSelected == stopIndex ? null : stopIndex;
    });
  }

  /// Stylized preview used when no raster is available. Selection is still
  /// forwarded so the stop list and the map stay in sync either way.
  Widget _fallbackPreview() {
    return RouteMapPreview(
      stops: widget.stops,
      geometry: widget.geometry,
      selectedIndex: _selectedStopIndex,
      onPinTap: _selectStop,
      height: widget.height,
      footerLabel: widget.footerLabel,
    );
  }

  List<RouteStop> get _locatedStops => [
    for (final stop in widget.stops)
      if (stop.lat != null && stop.lng != null) stop,
  ];

  List<({double lat, double lng})> _fitPoints() {
    return [
      for (final stop in _locatedStops) (lat: stop.lat!, lng: stop.lng!),
      for (final point
          in widget.geometry?.coordinates ?? const <RouteCoordinate>[])
        (lat: point.lat, lng: point.lng),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final located = _locatedStops;
    if (located.isEmpty || _imageFailed || widget.staticMapUrl == null) {
      return _fallbackPreview();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final projection = MapProjection.fit(
              points: _fitPoints(),
              size: size,
            );
            if (projection == null) {
              return _fallbackPreview();
            }
            final image = _mapImage(projection, size);
            final selectedIndex = _selectedStopIndex;
            final selectedStop =
                (selectedIndex != null &&
                    selectedIndex >= 0 &&
                    selectedIndex < widget.stops.length &&
                    widget.stops[selectedIndex].lat != null &&
                    widget.stops[selectedIndex].lng != null)
                ? widget.stops[selectedIndex]
                : null;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: widget.interactive
                        ? () => _openFullScreen(context)
                        : null,
                    child: image == null
                        ? const ColoredBox(color: AppColors.controlSurface)
                        : Image(
                            image: image,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) {
                              // One rebuild into the stylized fallback; the
                              // raster is unavailable for this session.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && !_imageFailed) {
                                  setState(() => _imageFailed = true);
                                }
                              });
                              return const ColoredBox(
                                color: AppColors.controlSurface,
                              );
                            },
                          ),
                  ),
                ),
                for (final stop in located) _positionedPin(projection, stop),
                if (selectedStop != null)
                  _StopCallout(
                    stop: selectedStop,
                    config: widget.config,
                    anchor: projection.toPixel(
                      selectedStop.lat!,
                      selectedStop.lng!,
                    ),
                    viewport: size,
                    onClose: () =>
                        _selectStop(widget.stops.indexOf(selectedStop)),
                  ),
                if (widget.footerLabel != null && selectedStop == null)
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          widget.footerLabel!,
                          style: AppTypography.button.copyWith(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positionedPin(MapProjection projection, RouteStop stop) {
    final stopIndex = widget.stops.indexOf(stop);
    final pixel = projection.toPixel(stop.lat!, stop.lng!);
    final selected = _selectedStopIndex == stopIndex;
    return Positioned(
      left: pixel.dx - 17,
      top: pixel.dy - 17,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Точка ${stop.position}, ${stop.placeName}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectStop(stopIndex),
          child: _MapPinDot(label: '${stop.position}', selected: selected),
        ),
      ),
    );
  }

  ImageProvider<Object>? _mapImage(MapProjection projection, Size size) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final scale = devicePixelRatio >= 2 ? 2 : 1;
    final path =
        '${widget.staticMapUrl}'
        '?width=${size.width.round()}'
        '&height=${size.height.round()}'
        '&scale=$scale'
        '&center_lat=${projection.centerLat.toStringAsFixed(6)}'
        '&center_lng=${projection.centerLng.toStringAsFixed(6)}'
        '&zoom=${projection.zoom}'
        '&pins=none';
    final resolved = AppImages.resolveMediaUrl(widget.config, path);
    if (resolved == null) return null;
    return AppImages.imageProvider(resolvedUrl: resolved);
  }

  void _openFullScreen(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullScreenRouteMap(
            staticMapUrl: widget.staticMapUrl,
            stops: widget.stops,
            geometry: widget.geometry,
            config: widget.config,
          ),
        ),
      ),
    );
  }
}

class _MapPinDot extends StatelessWidget {
  const _MapPinDot({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryInk : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : AppColors.primaryInk,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.button.copyWith(
          fontSize: 14,
          color: selected ? Colors.white : AppColors.primaryInk,
        ),
      ),
    );
  }
}

/// Small preview shown next to a tapped pin.
///
/// Flips above/below the pin depending on which side has room, so it never
/// runs off the top or bottom of the map.
class _StopCallout extends StatelessWidget {
  const _StopCallout({
    required this.stop,
    required this.config,
    required this.anchor,
    required this.viewport,
    required this.onClose,
  });

  static const double _width = 232;
  static const double _height = 84;
  static const double _gap = 24;

  final RouteStop stop;
  final AppConfig config;
  final Offset anchor;
  final Size viewport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fitsAbove = anchor.dy - _gap - _height >= 4;
    final top = fitsAbove ? anchor.dy - _gap - _height : anchor.dy + _gap;
    final left = (anchor.dx - _width / 2).clamp(
      6.0,
      (viewport.width - _width - 6).clamp(6.0, double.infinity),
    );
    final description = stop.placeShortDescription?.trim();

    return Positioned(
      left: left,
      top: top.clamp(4.0, viewport.height - _height - 4),
      width: _width,
      child: Material(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        child: InkWell(
          onTap: onClose,
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: _height,
                  child: AppImages.coverImage(
                    config: config,
                    coverImageUrl: stop.placeCoverUrl,
                    fallbackSeed: stop.placeId,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.placeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowTitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.settingsRowSubtitle.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _FullScreenRouteMap extends StatelessWidget {
  const _FullScreenRouteMap({
    required this.staticMapUrl,
    required this.stops,
    required this.geometry,
    required this.config,
  });

  /// Backend preview endpoint for this route, or null when the server does
  /// not offer one — then the stylized fallback is used instead of a raster.
  final String? staticMapUrl;
  final List<RouteStop> stops;
  final RouteGeometry? geometry;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        title: const Text('Карта маршрута'),
        backgroundColor: AppColors.pageSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: LayoutBuilder(
              builder: (context, constraints) => RouteStaticMap(
                staticMapUrl: staticMapUrl,
                stops: stops,
                geometry: geometry,
                config: config,
                height: constraints.maxHeight,
                // Already full screen: tapping should not stack another one.
                interactive: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
