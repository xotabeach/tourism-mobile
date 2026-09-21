import 'package:flutter/widgets.dart';

import 'package:tourism_mobile/core/startup/krymtrip_logo_data.dart';
import 'package:tourism_mobile/core/startup/svg_path.dart';

/// The white КРЫМТРИП wordmark (castle, gull and lettering), drawn from the
/// brand vector. The logo's paths are parsed once and reused.
class KrymtripLogo extends StatelessWidget {
  const KrymtripLogo({super.key, this.width = 209, this.opacity = 1});

  final double width;
  final double opacity;

  static final Path _path = () {
    final path = Path();
    for (final data in krymtripLogoPathData) {
      path.addPath(parseSvgPath(data), Offset.zero);
    }
    return path;
  }();

  @override
  Widget build(BuildContext context) {
    final height = width * krymtripLogoSize.height / krymtripLogoSize.width;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _LogoPainter(opacity),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / krymtripLogoSize.width;
    canvas
      ..save()
      ..scale(scale);
    canvas.drawPath(
      KrymtripLogo._path,
      Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
