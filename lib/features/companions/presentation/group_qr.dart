import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

// A group's code as a QR (FRONTEND-63, spec 11b D2): shown on the gathering
// screen, read by the camera from «У меня есть код». No links: the app does
// not open outside URLs, so the QR carries only the code with a marker.

const _prefix = 'krymtrip:group:';

/// What the QR of a group with [code] holds.
String groupQrPayload(String code) => '$_prefix${code.toUpperCase()}';

/// The group code inside a scanned QR, or null when it is not ours. A bare
/// code (someone printed just the letters) is accepted too.
String? parseGroupQr(String raw) {
  final text = raw.trim();
  final candidate = text.toLowerCase().startsWith(_prefix)
      ? text.substring(_prefix.length)
      : text;
  final code = candidate.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9]{4,8}$').hasMatch(code) ? code : null;
}

/// The QR itself, dark on white so any camera reads it: round dots with
/// rounded square eyes, as on the mockup.
class GroupQrImage extends StatelessWidget {
  const GroupQrImage({
    required this.code,
    this.size = 220,
    this.quiet = 0.06,
    super.key,
  });

  final String code;
  final double size;

  /// The white margin, a share of [size]; 0 inside a framed white board.
  final double quiet;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'QR-код группы $code',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: GroupQrPainter(groupQrPayload(code), quiet: quiet),
      ),
    ),
  );
}

class GroupQrPainter extends CustomPainter {
  GroupQrPainter(this.data, {this.quiet = 0.06})
    : _image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.H),
      );

  final String data;
  final double quiet;
  final QrImage _image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = _image.moduleCount;
    final margin = size.width * quiet;
    final m = (size.width - margin * 2) / n;
    final ink = Paint()..color = FlatPalette.ink;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    bool inEye(int r, int c) =>
        (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (inEye(r, c) || !_image.isDark(r, c)) continue;
        canvas.drawCircle(
          Offset(margin + (c + 0.5) * m, margin + (r + 0.5) * m),
          m * 0.32,
          ink,
        );
      }
    }
    for (final (r, c) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
      final outer = Rect.fromLTWH(margin + c * m, margin + r * m, 7 * m, 7 * m);
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.deflate(m / 2), Radius.circular(m * 1.6)),
        Paint()
          ..color = FlatPalette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = m * 0.9,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.deflate(2 * m), Radius.circular(m * 0.8)),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GroupQrPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.quiet != quiet;
}

/// The group's QR large, for someone standing next to you.
Future<void> showGroupQrSheet(BuildContext context, String code) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Наведите камеру',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'В приложении на странице маршрута: «Пройти вместе», затем '
                '«У меня есть код» и «Сканировать QR»',
                textAlign: TextAlign.center,
                style: AppTypography.settingsRowSubtitle,
              ),
              const SizedBox(height: 16),
              GroupQrImage(code: code, size: 240),
              const SizedBox(height: 12),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                  color: FlatPalette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );

/// Opens the camera and returns the first group code it reads, or null.
Future<String?> scanGroupQr(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<String>(MaterialPageRoute(builder: (_) => const GroupQrScannerScreen()));

class GroupQrScannerScreen extends StatefulWidget {
  const GroupQrScannerScreen({super.key});

  @override
  State<GroupQrScannerScreen> createState() => _GroupQrScannerScreenState();
}

class _GroupQrScannerScreenState extends State<GroupQrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _done = false;
  var _foreign = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final code = parseGroupQr(raw);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    // A QR that is not a group's: say so instead of staying silent.
    if (!_foreign && mounted) setState(() => _foreign = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('QR-код группы'),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Нет доступа к камере. Разрешите его в настройках '
                          'телефона или введите код вручную.'
                    : 'Камера недоступна. Введите код вручную.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        // The frame to aim at.
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Text(
            _foreign
                ? 'Это не QR-код группы КрымТрипа'
                : 'Наведите на QR-код с экрана сбора группы',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
