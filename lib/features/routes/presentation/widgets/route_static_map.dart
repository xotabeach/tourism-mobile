import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_interactive_map.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';

/// The expanded map is the interactive one (spec 12a-9) except under
/// `flutter test`, which has no platform views; tests may flip it.
@visibleForTesting
bool debugInteractiveRouteMap = !Platform.environment.containsKey(
  'FLUTTER_TEST',
);

/// Replaces the network raster in tests, keyed by the requested URL.
@visibleForTesting
ImageProvider<Object> Function(String url)? debugRouteMapImage;

/// A raster together with the projection it was requested for. Pins and
/// lines are always drawn with the projection of the raster on screen, never
/// with one computed for a frame that has not arrived yet.
class _MapFrame {
  const _MapFrame({
    required this.url,
    required this.image,
    required this.projection,
    required this.focus,
  });

  final String url;
  final ImageProvider<Object> image;
  final MapProjection projection;
  final bool focus;
}

/// The stretch between the last marked stop and the next one, highlighted on
/// the map while a route is being walked.
class ActiveLeg {
  const ActiveLeg({
    required this.line,
    required this.from,
    required this.to,
    this.pieces = const [],
  });

  /// The part of the route line between the two stops.
  final List<({double lat, double lng})> line;

  /// The leg's segments when it is driven with walks; drawn instead of
  /// [line], each dashed or solid by its own way (spec 14b).
  final List<({bool dashed, List<({double lat, double lng})> line})> pieces;
  final ({double lat, double lng}) from;
  final ({double lat, double lng}) to;
}

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
    this.pillFooter = false,
    this.interactive = true,
    this.selectedIndex,
    this.onStopTap,
    this.livePosition,
    this.completedFraction,
    this.completedStopPositions = const {},
    this.activeLeg,
    this.focusOnLeg = false,
    this.onLegFocusUnavailable,
    this.imageHeaders = const {},
    this.dashedLine = false,
    this.segments = const [],
    super.key,
  });

  /// Called when the zoomed-in leg frame could not be loaded (offline) and
  /// the whole route is shown instead, so the caller can say so.
  final VoidCallback? onLegFocusUnavailable;

  /// Segments of the route, for the expanded interactive map to draw each
  /// in its own way (spec 12a-9).
  final List<RouteSegment> segments;

  /// The route is walked: the progress and active-leg lines are dashed like
  /// the route line on the server's image (spec 14, D23). See
  /// [isWalkingMode].
  final bool dashedLine;

  /// Highlighted with an accent line when given.
  final ActiveLeg? activeLeg;

  /// Frame the map on [activeLeg] instead of the whole route. The raster is
  /// requested again for the new frame, so callers switch this only on a
  /// deliberate user action, never on every mark.
  final bool focusOnLeg;

  /// Backend preview endpoint for this route, or null when the server does
  /// not offer one — then the stylized fallback is used instead of a raster.
  final String? staticMapUrl;
  final List<RouteStop> stops;
  final AppConfig config;
  final RouteGeometry? geometry;
  final double height;
  final String? footerLabel;

  /// The route run screen draws the footer as a translucent pill with a thin
  /// light edge instead of the dark tag.
  final bool pillFooter;

  /// Whether tapping opens the zoomable full-screen map.
  final bool interactive;

  /// Index into [stops] of the highlighted stop. When [onStopTap] is given the
  /// selection is owned by the parent, so tapping a pin also highlights the
  /// matching row in the stop list (and vice versa).
  final int? selectedIndex;
  final ValueChanged<int>? onStopTap;

  /// The walker's current GPS fix, if a caller is tracking live location
  /// (route execution) and it's available. Drawn as an overlay on the same
  /// already-loaded raster via [MapProjection] — no live map SDK needed.
  final ({double lat, double lng})? livePosition;

  /// Fraction (0–1) of [geometry] walked so far — see
  /// [MapProjection.completedFraction]. Drawn as a colored overlay on top of
  /// the vendor's own route line, from the start up to that point. Null (the
  /// default) draws nothing, so callers with no execution in progress (e.g.
  /// the route details screen) see no change.
  final double? completedFraction;

  /// `position` of every stop already checked off, so the map can mark them
  /// done. Without it a walk in progress looks identical to one not started:
  /// [completedFraction] alone stays 0 until the walker leaves the first
  /// stop, which sits on the geometry's very first point.
  final Set<int> completedStopPositions;
  final Map<String, String> imageHeaders;

  @override
  State<RouteStaticMap> createState() => _RouteStaticMapState();
}

class _RouteStaticMapState extends State<RouteStaticMap> {
  int? _uncontrolledSelected;
  var _imageFailed = false;

  /// The zoomed-in frame could not be loaded (typically offline, where only
  /// the whole-route raster was downloaded): fall back to that frame and keep
  /// the leg highlight instead of dropping to the schematic preview.
  var _focusFailed = false;

  bool get _focusActive =>
      widget.focusOnLeg && widget.activeLeg != null && !_focusFailed;

  /// Raster currently on screen; the requested one replaces it only once it
  /// has loaded, so a switch of frame never shows the old basemap under the
  /// new frame's pins and lines.
  _MapFrame? _shown;
  _MapFrame? _pending;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didUpdateWidget(covariant RouteStaticMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusOnLeg != widget.focusOnLeg) _focusFailed = false;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  /// Starts loading [frame] unless it is already on screen or on its way.
  void _request(_MapFrame frame) {
    if (frame.url == _pending?.url) return;
    _stopListening();
    if (frame.url == _shown?.url) {
      // Back on the frame already on screen: a late answer for the one the
      // user switched away from must not replace it.
      _pending = null;
      return;
    }
    _pending = frame;
    final stream = frame.image.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (_, _) {
        if (!mounted || _pending?.url != frame.url) return;
        _stopListening();
        setState(() {
          _shown = frame;
          _pending = null;
        });
      },
      onError: (_, _) {
        if (!mounted || _pending?.url != frame.url) return;
        _stopListening();
        setState(() {
          _pending = null;
          // The zoomed-in frame falls back to the whole route; without any
          // raster the stylized preview takes over for this session.
          if (frame.focus) {
            _focusFailed = true;
            widget.onLegFocusUnavailable?.call();
          } else {
            _imageFailed = true;
          }
        });
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

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
      _uncontrolledSelected = _uncontrolledSelected == stopIndex
          ? null
          : stopIndex;
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
      dashedLine: widget.dashedLine,
    );
  }

  List<RouteStop> get _locatedStops => [
    for (final stop in widget.stops)
      if (stop.lat != null && stop.lng != null) stop,
  ];

  List<({double lat, double lng})> _fitPoints() {
    final leg = widget.activeLeg;
    if (_focusActive && leg != null) {
      return [leg.from, leg.to];
    }
    return [
      for (final stop in _locatedStops) (lat: stop.lat!, lng: stop.lng!),
      for (final point
          in widget.geometry?.coordinates ?? const <RouteCoordinate>[])
        (lat: point.lat, lng: point.lng),
      if (widget.livePosition != null) widget.livePosition!,
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
            final wanted = MapProjection.fit(points: _fitPoints(), size: size);
            if (wanted == null) {
              return _fallbackPreview();
            }
            final requested = _mapFrame(wanted, size);
            if (requested != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _request(requested);
              });
            }
            final shown = _shown;
            final current = shown != null && shown.projection.size == size
                ? shown
                : null;
            final projection = current?.projection ?? wanted;
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
                    child: current == null
                        ? const ColoredBox(color: AppColors.controlSurface)
                        : Image(
                            image: current.image,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.controlSurface,
                            ),
                          ),
                  ),
                ),
                if (_progressPoints(projection) case final points?
                    when points.length >= 2)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _RouteProgressPainter(
                          points,
                          dashed: widget.dashedLine,
                        ),
                      ),
                    ),
                  ),
                if (widget.activeLeg case final leg? when leg.line.length >= 2)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ActiveLegPainter(
                          leg.pieces.isEmpty
                              ? [
                                  (
                                    dashed: widget.dashedLine,
                                    points: [
                                      for (final point in leg.line)
                                        projection.toPixel(
                                          point.lat,
                                          point.lng,
                                        ),
                                    ],
                                  ),
                                ]
                              : [
                                  for (final piece in leg.pieces)
                                    (
                                      dashed: piece.dashed,
                                      points: [
                                        for (final point in piece.line)
                                          projection.toPixel(
                                            point.lat,
                                            point.lng,
                                          ),
                                      ],
                                    ),
                                ],
                        ),
                      ),
                    ),
                  ),
                for (final stop in located) _positionedPin(projection, stop),
                if (widget.livePosition != null)
                  _positionedLiveMarker(projection, widget.livePosition!),
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
                    left: widget.pillFooter ? 16 : 14,
                    bottom: widget.pillFooter ? 16 : 12,
                    child: widget.pillFooter
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xB31B2426),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: Text(
                                widget.footerLabel!,
                                style: const TextStyle(
                                  fontFamily: AppFonts.rubik,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : DecoratedBox(
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
    final completed = widget.completedStopPositions.contains(stop.position);
    return Positioned(
      left: pixel.dx - 17,
      top: pixel.dy - 17,
      child: Semantics(
        button: true,
        selected: selected,
        label: completed
            ? 'Точка ${stop.position}, ${stop.placeName}, пройдена'
            : 'Точка ${stop.position}, ${stop.placeName}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectStop(stopIndex),
          child: _MapPinDot(
            label: '${stop.position}',
            selected: selected,
            completed: completed,
          ),
        ),
      ),
    );
  }

  Widget _positionedLiveMarker(
    MapProjection projection,
    ({double lat, double lng}) position,
  ) {
    final pixel = projection.toPixel(position.lat, position.lng);
    return Positioned(
      left: pixel.dx - 10,
      top: pixel.dy - 10,
      child: IgnorePointer(
        child: Semantics(label: 'Ваше местоположение', child: const _LiveDot()),
      ),
    );
  }

  /// Projected pixel points for the walked portion of [widget.geometry], up
  /// to [widget.completedFraction]. Null when there's nothing to draw.
  List<Offset>? _progressPoints(MapProjection projection) {
    final fraction = widget.completedFraction;
    final coordinates = widget.geometry?.coordinates;
    if (fraction == null || coordinates == null || coordinates.length < 2) {
      return null;
    }
    final clamped = fraction.clamp(0.0, 1.0);
    final exactIndex = clamped * (coordinates.length - 1);
    final wholeIndex = exactIndex.floor().clamp(0, coordinates.length - 1);
    final points = [
      for (var i = 0; i <= wholeIndex; i++)
        projection.toPixel(coordinates[i].lat, coordinates[i].lng),
    ];
    final segmentT = exactIndex - wholeIndex;
    if (segmentT > 0 && wholeIndex < coordinates.length - 1) {
      final a = coordinates[wholeIndex];
      final b = coordinates[wholeIndex + 1];
      points.add(
        projection.toPixel(
          a.lat + (b.lat - a.lat) * segmentT,
          a.lng + (b.lng - a.lng) * segmentT,
        ),
      );
    }
    return points;
  }

  _MapFrame? _mapFrame(MapProjection projection, Size size) {
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
    ImageProvider<Object> image;
    if (debugRouteMapImage case final override?) {
      image = override(resolved);
    } else if (widget.imageHeaders.isNotEmpty) {
      // Auth headers are only attached to the application's own API.
      final target = Uri.tryParse(resolved);
      final api = Uri.tryParse(widget.config.apiBaseUrl);
      if (target == null || api == null || target.origin != api.origin) {
        return null;
      }
      image = NetworkImage(resolved, headers: widget.imageHeaders);
    } else {
      image = AppImages.imageProvider(resolvedUrl: resolved);
    }
    return _MapFrame(
      url: resolved,
      image: image,
      projection: projection,
      focus: _focusActive,
    );
  }

  void _openFullScreen(BuildContext context) {
    unawaited(showRouteMapFullScreen(context, widget));
  }
}

/// The expanded map for [map]'s route; [focusOnLeg] opens it framed on the
/// active leg (the run screen's «Участок на карте», FRONTEND-22).
Future<void> showRouteMapFullScreen(
  BuildContext context,
  RouteStaticMap map, {
  bool focusOnLeg = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenRouteMap(
        staticMapUrl: map.staticMapUrl,
        stops: map.stops,
        geometry: map.geometry,
        config: map.config,
        livePosition: map.livePosition,
        completedFraction: map.completedFraction,
        completedStopPositions: map.completedStopPositions,
        activeLeg: map.activeLeg,
        imageHeaders: map.imageHeaders,
        dashedLine: map.dashedLine,
        segments: map.segments,
        initialFocusOnLeg: focusOnLeg && map.activeLeg != null,
      ),
    ),
  );
}

/// Accent line over the active stretch, drawn above the walked-so-far line.
class _ActiveLegPainter extends CustomPainter {
  const _ActiveLegPainter(this.parts);

  final List<({bool dashed, List<Offset> points})> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final part in parts) {
      if (part.points.length < 2) continue;
      path.addPath(_linePath(part.points, dashed: part.dashed), Offset.zero);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accentBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveLegPainter oldDelegate) =>
      oldDelegate.parts.length != parts.length ||
      [
        for (var i = 0; i < parts.length; i++)
          parts[i].dashed != oldDelegate.parts[i].dashed ||
              !listEquals(parts[i].points, oldDelegate.parts[i].points),
      ].any((changed) => changed);
}

/// Overlays the walked portion of the route on top of the vendor's own
/// (uncolored) route line, from the start up to the current progress point.
class _RouteProgressPainter extends CustomPainter {
  const _RouteProgressPainter(this.points, {required this.dashed});

  final List<Offset> points;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _linePath(points, dashed: dashed);
    // A light halo first so the green reads on both light and dark basemap
    // tiles, same idea as the pins' white border.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.positiveSwipeTint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteProgressPainter oldDelegate) =>
      dashed != oldDelegate.dashed || !listEquals(points, oldDelegate.points);
}

/// A polyline through [points], dashed for a walked route.
Path _linePath(List<Offset> points, {required bool dashed}) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return dashed ? dashedPath(path) : path;
}

class _MapPinDot extends StatelessWidget {
  const _MapPinDot({
    required this.label,
    required this.selected,
    this.completed = false,
  });

  final String label;
  final bool selected;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.primaryInk
        : completed
        ? AppColors.statusCompleted
        : Colors.white;
    final foreground = selected || completed
        ? Colors.white
        : AppColors.primaryInk;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: foreground, width: 2),
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
        style: AppTypography.button.copyWith(fontSize: 14, color: foreground),
      ),
    );
  }
}

/// "You are here" marker for [RouteStaticMap.livePosition] — a solid dot
/// with a soft halo, distinct from the numbered stop pins.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentBlue.withValues(alpha: 0.22),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentBlue,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
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

class _FullScreenRouteMap extends StatefulWidget {
  const _FullScreenRouteMap({
    required this.staticMapUrl,
    required this.stops,
    required this.geometry,
    required this.config,
    this.livePosition,
    this.completedFraction,
    this.completedStopPositions = const {},
    this.activeLeg,
    this.imageHeaders = const {},
    this.dashedLine = false,
    this.segments = const [],
    this.initialFocusOnLeg = false,
  });

  /// Opened framed on the active leg rather than the whole route.
  final bool initialFocusOnLeg;

  /// Backend preview endpoint for this route, or null when the server does
  /// not offer one — then the stylized fallback is used instead of a raster.
  final String? staticMapUrl;
  final List<RouteStop> stops;
  final RouteGeometry? geometry;
  final AppConfig config;

  /// Carried over from the inline map — without it, expanding to full
  /// screen during a live run silently drops the "you are here" marker.
  final ({double lat, double lng})? livePosition;

  /// Carried over from the inline map — see [RouteStaticMap.completedFraction].
  final double? completedFraction;

  /// Carried over from the inline map — see
  /// [RouteStaticMap.completedStopPositions].
  final Set<int> completedStopPositions;
  final ActiveLeg? activeLeg;
  final Map<String, String> imageHeaders;
  final bool dashedLine;
  final List<RouteSegment> segments;

  @override
  State<_FullScreenRouteMap> createState() => _FullScreenRouteMapState();
}

class _FullScreenRouteMapState extends State<_FullScreenRouteMap> {
  late var _focusLeg = widget.initialFocusOnLeg;

  /// The leg frame could not be loaded: the whole route is on screen.
  var _legFocusUnavailable = false;

  /// The interactive map could not load (offline): the picture instead.
  var _interactiveFailed = false;

  /// Pinch zoom belongs to the frame it was made on: a new frame starts from
  /// its own fitted scale.
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLeg = widget.activeLeg != null;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        title: const Text('Карта маршрута'),
        backgroundColor: AppColors.pageSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Column(
                children: [
                  if (debugInteractiveRouteMap && !_interactiveFailed)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: RouteInteractiveMap(
                          config: widget.config,
                          stops: widget.stops,
                          geometry: widget.geometry,
                          segments: widget.segments,
                          dashedLine: widget.dashedLine,
                          livePosition: widget.livePosition,
                          completedStopPositions: widget.completedStopPositions,
                          activeLeg: widget.activeLeg?.line,
                          focusOnLeg: _focusLeg,
                          // The same place card as on the picture map.
                          calloutBuilder: (stop, anchor, viewport, onClose) =>
                              _StopCallout(
                                stop: stop,
                                config: widget.config,
                                anchor: anchor,
                                viewport: viewport,
                                onClose: onClose,
                              ),
                          onUnavailable: () =>
                              setState(() => _interactiveFailed = true),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: InteractiveViewer(
                        transformationController: _zoom,
                        minScale: 1,
                        maxScale: 6,
                        child: LayoutBuilder(
                          builder: (context, constraints) => RouteStaticMap(
                            staticMapUrl: widget.staticMapUrl,
                            stops: widget.stops,
                            geometry: widget.geometry,
                            config: widget.config,
                            height: constraints.maxHeight,
                            livePosition: widget.livePosition,
                            completedFraction: widget.completedFraction,
                            completedStopPositions:
                                widget.completedStopPositions,
                            activeLeg: widget.activeLeg,
                            focusOnLeg: _focusLeg,
                            onLegFocusUnavailable: () {
                              if (mounted && !_legFocusUnavailable) {
                                setState(() => _legFocusUnavailable = true);
                              }
                            },
                            imageHeaders: widget.imageHeaders,
                            dashedLine: widget.dashedLine,
                            // Already full screen: tapping should not stack another one.
                            interactive: false,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (hasLeg)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: LegFocusToggle(
                      focusOnLeg: _focusLeg,
                      onChanged: (value) => setState(() {
                        _focusLeg = value;
                        _legFocusUnavailable = false;
                        _zoom.value = Matrix4.identity();
                      }),
                    ),
                  ),
                ),
              if (hasLeg && _focusLeg && _legFocusUnavailable)
                const Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _MapNotice(
                    text:
                        'Без сети участок не приблизить. Показан весь маршрут, '
                        'участок выделен.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Участок / Весь маршрут» over the expanded map (FRONTEND-22). A floating
/// pill so the map keeps the whole screen; the active side is filled.
class LegFocusToggle extends StatelessWidget {
  const LegFocusToggle({
    required this.focusOnLeg,
    required this.onChanged,
    super.key,
  });

  final bool focusOnLeg;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleSide(
              label: 'Весь маршрут',
              selected: !focusOnLeg,
              onTap: () => onChanged(false),
            ),
            _ToggleSide(
              label: 'Участок',
              selected: focusOnLeg,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSide extends StatelessWidget {
  const _ToggleSide({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.primaryInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// A short note over the map, e.g. why the leg is not zoomed in.
class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryInk.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  height: 1.25,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
