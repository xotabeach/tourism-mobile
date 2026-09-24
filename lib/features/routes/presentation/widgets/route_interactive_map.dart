import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_geojson.dart';

/// A real map for the expanded route view (spec 12a-9, D27/D28): our style
/// and vector tiles from `/map/` on the API host, drawn by MapLibre, with
/// the route line by segment, numbered stops, the active leg and the
/// walker's position. Zoom and pan are the map's own, not a stretched
/// picture (FRONTEND-44).
///
/// [onUnavailable] fires when the style does not load in time — offline,
/// most often — so the caller can show the downloaded picture instead.
class RouteInteractiveMap extends StatefulWidget {
  const RouteInteractiveMap({
    required this.config,
    required this.stops,
    required this.onUnavailable,
    this.geometry,
    this.segments = const [],
    this.dashedLine = false,
    this.livePosition,
    this.completedStopPositions = const {},
    this.activeLeg,
    this.focusOnLeg = false,
    this.calloutBuilder,
    super.key,
  });

  /// The place card for a tapped stop, placed at [anchor] (logical pixels
  /// from the map's top left) — the same card the picture map shows.
  final Widget Function(
    RouteStop stop,
    Offset anchor,
    Size viewport,
    VoidCallback onClose,
  )?
  calloutBuilder;

  final AppConfig config;
  final List<RouteStop> stops;
  final RouteGeometry? geometry;
  final List<RouteSegment> segments;
  final bool dashedLine;
  final MapPoint? livePosition;
  final Set<int> completedStopPositions;

  /// Line of the active leg, highlighted over the route.
  final List<MapPoint>? activeLeg;

  /// Frame the active leg instead of the whole route.
  final bool focusOnLeg;
  final VoidCallback onUnavailable;

  /// Style of our map, served by tileserver-gl behind Caddy.
  static String styleUrl(AppConfig config) =>
      '${config.apiBaseUrl}/map/styles/crimeatrip/style.json';

  @override
  State<RouteInteractiveMap> createState() => _RouteInteractiveMapState();
}

class _RouteInteractiveMapState extends State<RouteInteractiveMap> {
  static const _loadTimeout = Duration(seconds: 8);
  static const _singlePointZoom = 14.0;
  static const _padding = 56.0;

  MapLibreMapController? _controller;
  var _styleLoaded = false;
  Timer? _timeout;

  /// The tapped stop and where its pin is on screen, for the place card.
  RouteStop? _selected;
  Offset? _anchor;
  static const _tapRadius = 28.0;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(_loadTimeout, () {
      if (mounted && !_styleLoaded) widget.onUnavailable();
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RouteInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    if (oldWidget.livePosition != widget.livePosition) {
      unawaited(
        controller.setGeoJsonSource('me', pointGeoJson(widget.livePosition)),
      );
    }
    if (oldWidget.completedStopPositions != widget.completedStopPositions) {
      unawaited(
        controller.setGeoJsonSource(
          'stops',
          stopsGeoJson(
            widget.stops,
            completedPositions: widget.completedStopPositions,
          ),
        ),
      );
    }
    if (oldWidget.activeLeg != widget.activeLeg) {
      unawaited(
        controller.setGeoJsonSource(
          'leg',
          lineGeoJson(widget.activeLeg ?? const []),
        ),
      );
    }
    if (oldWidget.focusOnLeg != widget.focusOnLeg) {
      unawaited(_frame(animate: true));
    }
  }

  List<MapPoint> get _allPoints => [
    for (final stop in widget.stops)
      if (stop.lat != null && stop.lng != null)
        (lat: stop.lat!, lng: stop.lng!),
    for (final c in widget.geometry?.coordinates ?? const <RouteCoordinate>[])
      (lat: c.lat, lng: c.lng),
  ];

  Future<void> _frame({required bool animate}) async {
    final controller = _controller;
    if (controller == null) return;
    final leg = widget.activeLeg;
    final points = widget.focusOnLeg && leg != null && leg.length >= 2
        ? leg
        : _allPoints;
    final bounds = boundsOf(points);
    if (bounds == null) return;
    final CameraUpdate update;
    if (bounds.southWest == bounds.northEast) {
      update = CameraUpdate.newLatLngZoom(
        LatLng(bounds.southWest.lat, bounds.southWest.lng),
        _singlePointZoom,
      );
    } else {
      update = CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds.southWest.lat, bounds.southWest.lng),
          northeast: LatLng(bounds.northEast.lat, bounds.northEast.lng),
        ),
        left: _padding,
        top: _padding,
        right: _padding,
        bottom: _padding,
      );
    }
    await (animate
        ? controller.animateCamera(update)
        : controller.moveCamera(update));
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    setState(() => _styleLoaded = true);
    _timeout?.cancel();
    await controller.addGeoJsonSource(
      'route',
      routeLinesGeoJson(
        geometry: widget.geometry,
        segments: widget.segments,
        dashed: widget.dashedLine,
      ),
    );
    const color = [
      'match',
      ['get', 'mode'],
      'walk',
      mapWalkColor,
      'car',
      mapCarColor,
      mapTransitColor,
    ];
    await controller.addLineLayer(
      'route',
      'route-solid',
      const LineLayerProperties(
        lineColor: color,
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: const [
        '==',
        ['get', 'dashed'],
        false,
      ],
      enableInteraction: false,
    );
    await controller.addLineLayer(
      'route',
      'route-dashed',
      const LineLayerProperties(
        lineColor: color,
        lineWidth: 5,
        lineDasharray: [2, 1.4],
      ),
      filter: const [
        '==',
        ['get', 'dashed'],
        true,
      ],
      enableInteraction: false,
    );
    await controller.addGeoJsonSource(
      'leg',
      lineGeoJson(widget.activeLeg ?? const []),
    );
    await controller.addLineLayer(
      'leg',
      'leg',
      LineLayerProperties(
        lineColor: mapActiveLegColor,
        lineWidth: 6,
        lineCap: 'round',
        lineDasharray: widget.dashedLine ? const [2, 1.4] : null,
      ),
      enableInteraction: false,
    );
    await controller.addGeoJsonSource(
      'stops',
      stopsGeoJson(
        widget.stops,
        completedPositions: widget.completedStopPositions,
      ),
    );
    await controller.addCircleLayer(
      'stops',
      'stops',
      const CircleLayerProperties(
        circleRadius: 12,
        circleColor: [
          'case',
          ['get', 'done'],
          mapWalkColor,
          '#111827',
        ],
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
      enableInteraction: false,
    );
    await controller.addSymbolLayer(
      'stops',
      'stop-numbers',
      const SymbolLayerProperties(
        textField: ['get', 'label'],
        // The only font our tileserver serves (Noto Sans).
        textFont: ['Noto Sans Regular'],
        textSize: 12,
        textColor: '#FFFFFF',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
    await controller.addGeoJsonSource('me', pointGeoJson(widget.livePosition));
    await controller.addCircleLayer(
      'me',
      'me',
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: mapActiveLegColor,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    );
    await _frame(animate: false);
  }

  /// Android reports map pixels as physical ones, iOS as logical points.
  double get _pixelRatio =>
      Platform.isAndroid ? MediaQuery.devicePixelRatioOf(context) : 1;

  Future<void> _onMapClick(math.Point<double> tap) async {
    final controller = _controller;
    if (controller == null || widget.calloutBuilder == null) return;
    final located = [
      for (final stop in widget.stops)
        if (stop.lat != null && stop.lng != null) stop,
    ];
    if (located.isEmpty) return;
    final screen = await controller.toScreenLocationBatch([
      for (final stop in located) LatLng(stop.lat!, stop.lng!),
    ]);
    final radius = _tapRadius * _pixelRatio;
    RouteStop? hit;
    var best = double.infinity;
    for (var i = 0; i < located.length && i < screen.length; i++) {
      final dx = screen[i].x - tap.x;
      final dy = screen[i].y - tap.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= radius && distance < best) {
        best = distance;
        hit = located[i];
      }
    }
    if (!mounted) return;
    if (hit == null) {
      setState(() => _selected = null);
      return;
    }
    _selected = hit;
    await _placeCallout();
  }

  /// Keeps the card on its pin after the camera moved.
  Future<void> _placeCallout() async {
    final controller = _controller;
    final stop = _selected;
    if (controller == null || stop == null) return;
    final point = await controller.toScreenLocation(
      LatLng(stop.lat!, stop.lng!),
    );
    if (!mounted) return;
    setState(
      () => _anchor = Offset(
        point.x.toDouble() / _pixelRatio,
        point.y.toDouble() / _pixelRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = boundsOf(_allPoints)?.southWest ?? (lat: 44.95, lng: 34.1);
    final selected = _selected;
    final anchor = _anchor;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          _map(start),
          if (selected != null &&
              anchor != null &&
              widget.calloutBuilder != null)
            widget.calloutBuilder!(
              selected,
              anchor,
              constraints.biggest,
              () => setState(() => _selected = null),
            ),
          // Until our style is in, a spinner rather than a blank map.
          if (!_styleLoaded)
            const ColoredBox(
              color: Color(0xFFF2EFE9),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _map(MapPoint start) {
    return MapLibreMap(
      styleString: RouteInteractiveMap.styleUrl(widget.config),
      initialCameraPosition: CameraPosition(
        target: LatLng(start.lat, start.lng),
        zoom: 9,
      ),
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
      onMapClick: (point, _) => unawaited(_onMapClick(point)),
      onCameraIdle: () => unawaited(_placeCallout()),
      compassEnabled: true,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      trackCameraPosition: false,
    );
  }
}
