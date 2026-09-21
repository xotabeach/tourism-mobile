import 'dart:ui';

/// Minimal SVG path-data parser: absolute M, L, H, V, C and Z, which is all
/// the brand logo uses. Kept tiny on purpose (no `flutter_svg` dependency for
/// a single vector); anything else throws so a new logo cannot silently
/// render wrong.
Path parseSvgPath(String data) {
  final path = Path();
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(data);
  final items = [for (final m in tokens) m.group(0)!];
  var i = 0;
  double next() => double.parse(items[i++]);
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  String? command;
  while (i < items.length) {
    final token = items[i];
    if (RegExp('[A-Za-z]').hasMatch(token)) {
      command = token;
      i++;
      if (command == 'Z') {
        path.close();
        x = startX;
        y = startY;
        continue;
      }
    } else if (command == null || command == 'Z') {
      throw FormatException('Unexpected number in path data: $token');
    }
    switch (command) {
      case 'M':
        x = next();
        y = next();
        startX = x;
        startY = y;
        path.moveTo(x, y);
        // Extra pairs after M are implicit lineto commands.
        command = 'L';
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      default:
        throw FormatException('Unsupported path command: $command');
    }
  }
  return path;
}
