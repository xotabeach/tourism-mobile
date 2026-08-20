import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Stylised route map with numbered pins.
///
/// Pins are placed from stop coordinates when they exist, otherwise the stops
/// are spread evenly across the canvas. Tapping a pin reports the stop index so
/// the screen can highlight the matching row in «Остановки».
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({
    required this.stops,
    required this.selectedIndex,
    required this.onPinTap,
    this.height = 260,
    this.footerLabel,
    super.key,
  });

  final List<RouteStop> stops;
  final int? selectedIndex;
  final ValueChanged<int> onPinTap;
  final double height;
  final String? footerLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final points = _pinOffsets(constraints.biggest);

            return Stack(
              children: [
                const Positioned.fill(child: _MapBackdrop()),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _RouteLinePainter(points)),
                  ),
                ),
                for (var index = 0; index < points.length; index++)
                  Positioned(
                    left: points[index].dx - 21,
                    top: points[index].dy - 21,
                    child: _MapPin(
                      position: stops[index].position,
                      label: stops[index].placeName,
                      selected: selectedIndex == index,
                      onTap: () => onPinTap(index),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    footerLabel ?? _pointsLabel(stops.length),
                    style: AppTypography.button.copyWith(
                      fontSize: 15,
                      color: Colors.white,
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

  List<Offset> _pinOffsets(Size size) {
    const inset = 44.0;
    final width = size.width - inset * 2;
    // Keeps pins clear of the «N точек маршрута» caption at the bottom.
    final usableHeight = size.height - inset - 64;
    if (stops.isEmpty) {
      return const [];
    }
    if (stops.length == 1) {
      return [Offset(size.width / 2, inset + usableHeight / 2)];
    }

    final lats = stops.map((stop) => stop.lat).whereType<double>().toList();
    final lngs = stops.map((stop) => stop.lng).whereType<double>().toList();
    final hasGeo = lats.length == stops.length && lngs.length == stops.length;

    if (!hasGeo) {
      return [
        for (var index = 0; index < stops.length; index++)
          Offset(
            inset + width * index / (stops.length - 1),
            inset + usableHeight * (index.isEven ? 0.28 : 0.72),
          ),
      ];
    }

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() < 1e-6 ? 1.0 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 1e-6 ? 1.0 : maxLng - minLng;

    return [
      for (final stop in stops)
        Offset(
          inset + width * ((stop.lng! - minLng) / lngSpan),
          // Latitude grows northwards, screen coordinates grow downwards.
          inset + usableHeight * (1 - (stop.lat! - minLat) / latSpan),
        ),
    ];
  }

  static String _pointsLabel(int count) {
    final lastTwo = count % 100;
    final last = count % 10;
    if (lastTwo >= 11 && lastTwo <= 14) {
      return '$count точек маршрута';
    }
    return switch (last) {
      1 => '$count точка маршрута',
      2 || 3 || 4 => '$count точки маршрута',
      _ => '$count точек маршрута',
    };
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11556F), Color(0xFF0B3D55)],
        ),
      ),
      child: CustomPaint(painter: _MapGridPainter()),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.position,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int position;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Точка $position, $label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 42,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              width: selected ? 38 : 32,
              height: selected ? 38 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primaryInk : Colors.white,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: selected ? 0.4 : 0.2),
                    blurRadius: selected ? 14 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$position',
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: selected ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: selected ? Colors.white : AppColors.primaryInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 14), paint);
    }
    for (var x = 30.0; x < size.width; x += 52) {
      canvas.drawLine(Offset(x, 0), Offset(x - 18, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
