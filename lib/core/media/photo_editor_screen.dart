import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/media/photo_crop_geometry.dart';

/// What the crop window is shaped for.
enum PhotoCropShape {
  /// Avatar — square window drawn as a circle.
  avatar(aspectRatio: 1, circular: true),

  /// Profile cover and route/article photos.
  wide(aspectRatio: 16 / 9),

  /// Article and review photos, where the author frames what they want.
  free(aspectRatio: 4 / 3);

  const PhotoCropShape({required this.aspectRatio, this.circular = false});

  final double aspectRatio;
  final bool circular;
}

/// Frames a photo before it is uploaded: pan, pinch, 90° rotation, and a fixed
/// crop window.
///
/// Every upload used to send the picked file untouched, so a portrait photo
/// became an avatar cropped by the viewer however it happened to fit
/// (asked 2026-09-04). Framing is the author's decision, not the layout's.
///
/// Returns the cropped PNG bytes, or null if the user backs out.
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({
    required this.source,
    this.shape = PhotoCropShape.free,
    this.title = 'Кадрирование',
    super.key,
  });

  final File source;
  final PhotoCropShape shape;
  final String title;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  ui.Image? _image;
  Object? _loadError;
  var _transform = const PhotoCropTransform();
  var _saving = false;

  /// Размер рамки, которым реально отрисовано превью. Кнопка «Готово» берёт
  /// именно его, а не пересчитывает по своим ограничениям: обрезать надо
  /// ровно то, что человек видел, а не то, что померила строка кнопок.
  Size _window = Size.zero;

  // Gesture bookkeeping — the scale at the start of a pinch, so zooming is
  // relative to where the fingers landed rather than jumping.
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() => _image = decoded);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Size _windowSize(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth - 32;
    final maxHeight = constraints.maxHeight - 32;
    var width = maxWidth;
    var height = width / widget.shape.aspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * widget.shape.aspectRatio;
    }
    return Size(width, height);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _transform.scale;
    _gestureStartOffset = _transform.offset;
    _gestureStartFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size image, Size window) {
    final scale = (_gestureStartScale * details.scale).clamp(1.0, 6.0);
    final base = coverScale(image, window, _transform.quarterTurns);
    final moved = details.focalPoint - _gestureStartFocal;
    setState(() {
      _transform = _transform.copyWith(
        scale: scale,
        offset: clampOffset(
          offset: _gestureStartOffset + moved,
          image: image,
          window: window,
          scale: base * scale,
          quarterTurns: _transform.quarterTurns,
        ),
      );
    });
  }

  void _rotate(Size image, Size window) {
    setState(() {
      final turns = _transform.quarterTurns + 1;
      final next = _transform.copyWith(quarterTurns: turns);
      // Rotating changes which way the photo is longer, so the old pan can
      // suddenly expose an edge — re-clamp against the new orientation.
      _transform = next.copyWith(
        offset: clampOffset(
          offset: next.offset,
          image: image,
          window: window,
          scale: coverScale(image, window, next.quarterTurns) * next.scale,
          quarterTurns: next.quarterTurns,
        ),
      );
    });
  }

  void _reset() {
    setState(() => _transform = const PhotoCropTransform());
  }

  Future<void> _apply(Size window) async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await renderCroppedPhoto(
        image: image,
        window: window,
        transform: _transform,
      );
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось обрезать фото')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTypography.sectionTitle.copyWith(color: Colors.white),
        ),
        actions: [
          // «Готово» в шапке, а не внизу: снизу кнопку перекрывала
          // системная полоса жестов, и нажать её было нельзя
          // (жалоба 2026-09-04).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              key: const ValueKey('photo-editor-apply'),
              onPressed: _image == null || _saving || _window.isEmpty
                  ? null
                  : () => unawaited(_apply(_window)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white24,
                textStyle: AppTypography.chip.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_saving ? 'Готовим…' : 'Готово'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final image = _image;
                  if (_loadError != null) {
                    return const Center(
                      child: Text(
                        'Не удалось открыть фото',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (image == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  final window = _windowSize(constraints);
                  _window = window;
                  final imageSize = Size(
                    image.width.toDouble(),
                    image.height.toDouble(),
                  );
                  return Center(
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: (details) =>
                          _onScaleUpdate(details, imageSize, window),
                      child: ClipPath(
                        clipper: _WindowClipper(
                          shape: widget.shape,
                          window: window,
                        ),
                        child: SizedBox(
                          width: window.width,
                          height: window.height,
                          child: CustomPaint(
                            painter: _PreviewPainter(
                              image: image,
                              transform: _transform,
                              window: window,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Только поворот и сброс: «Готово» уехало в шапку. Отступ снизу
            // держит кнопки над системной полосой жестов, а не под ней.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Builder(
                builder: (context) {
                  final image = _image;
                  final window = _window;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _EditorAction(
                        icon: Icons.rotate_90_degrees_cw_rounded,
                        label: 'Повернуть',
                        onTap: image == null
                            ? null
                            : () => _rotate(
                                Size(
                                  image.width.toDouble(),
                                  image.height.toDouble(),
                                ),
                                window,
                              ),
                      ),
                      const SizedBox(width: 24),
                      _EditorAction(
                        icon: Icons.restart_alt_rounded,
                        label: 'Сбросить',
                        onTap: image == null ? null : _reset,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowClipper extends CustomClipper<Path> {
  const _WindowClipper({required this.shape, required this.window});

  final PhotoCropShape shape;
  final Size window;

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    if (shape.circular) {
      return Path()..addOval(rect);
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadii.card)),
    );
  }

  @override
  bool shouldReclip(_WindowClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.window != window;
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.image,
    required this.transform,
    required this.window,
  });

  final ui.Image image;
  final PhotoCropTransform transform;
  final Size window;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final scale =
        coverScale(imageSize, window, transform.quarterTurns) * transform.scale;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..translate(transform.offset.dx, transform.offset.dy)
      ..rotate(transform.quarterTurns * (3.1415926535897932 / 2))
      ..scale(scale);
    canvas.drawImage(
      image,
      Offset(-imageSize.width / 2, -imageSize.height / 2),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.transform.scale != transform.scale ||
      oldDelegate.transform.offset != transform.offset ||
      oldDelegate.transform.quarterTurns != transform.quarterTurns ||
      oldDelegate.window != window;
}

class _EditorAction extends StatelessWidget {
  const _EditorAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        tooltip: label,
      ),
    );
  }
}

/// Opens the editor for [source] and writes the framed result to a temp file.
///
/// Returns the path of the cropped file, or null if the user backed out. Call
/// sites upload this instead of the raw pick, so what the author framed is
/// what everyone sees.
Future<String?> cropPickedPhoto(
  BuildContext context, {
  required String sourcePath,
  PhotoCropShape shape = PhotoCropShape.free,
  String title = 'Кадрирование',
}) async {
  // rootNavigator: редактор должен накрыть весь экран. Без этого он
  // открывался внутри ветки-вкладки, и плавающая панель приложения со своей
  // белой подложкой оставалась поверх него (жалоба 2026-09-04).
  final bytes = await Navigator.of(context, rootNavigator: true)
      .push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          fullscreenDialog: true,
          builder: (_) => PhotoEditorScreen(
            source: File(sourcePath),
            shape: shape,
            title: title,
          ),
        ),
      );
  if (bytes == null) {
    return null;
  }
  final directory = await Directory.systemTemp.createTemp('crimeatrip-crop');
  final target = File(
    '${directory.path}/crop-${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}
