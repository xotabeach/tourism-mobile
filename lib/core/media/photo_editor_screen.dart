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
  free(aspectRatio: 4 / 3),

  /// Route photos: the frame takes the photo's own proportions, so nothing
  /// is cut off. Rotating and zooming still work — only the fixed 16:9
  /// window is gone, since a route photo is shown whole, not as a banner.
  original();

  const PhotoCropShape({this.aspectRatio, this.circular = false});

  /// `null` means "follow the photo" — see [original].
  final double? aspectRatio;
  final bool circular;
}

/// One photo's state inside the editor.
class _Frame {
  _Frame(this.source);

  final File source;
  ui.Image? image;
  Object? error;
  var transform = const PhotoCropTransform();

  bool get isReady => image != null;
}

/// Frames photos before they are uploaded: pan, pinch, 90° rotation, and a
/// crop window.
///
/// Every upload used to send the picked file untouched, so a portrait photo
/// became an avatar cropped by the viewer however it happened to fit
/// (asked 2026-09-04). Framing is the author's decision, not the layout's.
///
/// Takes a list because picking photos one at a time — gallery, crop, back to
/// the form, gallery again — is most of the work of adding a gallery. With
/// several, a strip along the bottom switches between them and each keeps its
/// own framing until the author is done with all of them.
///
/// Returns the cropped JPEG bytes in the order given, or null if the user
/// backs out.
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({
    required this.sources,
    this.shape = PhotoCropShape.free,
    this.title = 'Кадрирование',
    super.key,
  });

  final List<File> sources;
  final PhotoCropShape shape;
  final String title;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late final List<_Frame> _frames = [
    for (final source in widget.sources) _Frame(source),
  ];
  var _index = 0;
  var _saving = false;
  var _done = 0;

  /// Constraints the preview area was last laid out with.
  ///
  /// Not a window size: with several photos the window follows each photo's
  /// own proportions, so the size is derived per frame at the moment it is
  /// needed. Deliberately *not* part of whether «Готово» is enabled — it is
  /// written during layout, one frame after the button is built, and gating
  /// the button on it left it dead until some unrelated rebuild happened to
  /// run. People had to nudge the photo before they could confirm it
  /// (reported 2026-09-08).
  BoxConstraints? _constraints;

  // Gesture bookkeeping — the scale at the start of a pinch, so zooming is
  // relative to where the fingers landed rather than jumping.
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  _Frame get _current => _frames[_index];

  bool get _anyReady => _frames.any((frame) => frame.isReady);

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  /// Decodes the current photo first, then the rest.
  ///
  /// The author is looking at one photo; making them wait for the tenth to
  /// decode before the first appears would be the wrong order.
  Future<void> _loadAll() async {
    for (var i = 0; i < _frames.length; i++) {
      await _load(_frames[i]);
      if (!mounted) return;
    }
  }

  Future<void> _load(_Frame frame) async {
    if (frame.image != null || frame.error != null) {
      return;
    }
    try {
      final bytes = await frame.source.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      setState(() => frame.image = decoded);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => frame.error = error);
    }
  }

  @override
  void dispose() {
    for (final frame in _frames) {
      frame.image?.dispose();
    }
    super.dispose();
  }

  /// Aspect the crop window is drawn at. Follows the photo (as rotated) when
  /// the shape has none of its own, so `coverScale` lands on an exact fit and
  /// the whole picture survives.
  double _aspectRatioOf(_Frame frame) {
    final fixed = widget.shape.aspectRatio;
    if (fixed != null) {
      return fixed;
    }
    final image = frame.image;
    if (image == null) {
      return 4 / 3;
    }
    final rotated = rotatedImageSize(
      Size(image.width.toDouble(), image.height.toDouble()),
      frame.transform.quarterTurns,
    );
    if (rotated.width <= 0 || rotated.height <= 0) {
      return 4 / 3;
    }
    return rotated.width / rotated.height;
  }

  Size _windowFor(_Frame frame, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth - 32;
    final maxHeight = constraints.maxHeight - 32;
    final aspectRatio = _aspectRatioOf(frame);
    var width = maxWidth;
    var height = width / aspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    return Size(width, height);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _current.transform.scale;
    _gestureStartOffset = _current.transform.offset;
    _gestureStartFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size image, Size window) {
    final frame = _current;
    final scale = (_gestureStartScale * details.scale).clamp(1.0, 6.0);
    final base = coverScale(image, window, frame.transform.quarterTurns);
    final moved = details.focalPoint - _gestureStartFocal;
    setState(() {
      frame.transform = frame.transform.copyWith(
        scale: scale,
        offset: clampOffset(
          offset: _gestureStartOffset + moved,
          image: image,
          window: window,
          scale: base * scale,
          quarterTurns: frame.transform.quarterTurns,
        ),
      );
    });
  }

  void _rotate(Size image, Size window) {
    final frame = _current;
    setState(() {
      final turns = frame.transform.quarterTurns + 1;
      final next = frame.transform.copyWith(quarterTurns: turns);
      // Rotating changes which way the photo is longer, so the old pan can
      // suddenly expose an edge — re-clamp against the new orientation.
      frame.transform = next.copyWith(
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
    setState(() => _current.transform = const PhotoCropTransform());
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// Renders every readable photo with the framing it was given.
  Future<void> _apply() async {
    final constraints = _constraints;
    if (_saving || constraints == null) return;
    setState(() {
      _saving = true;
      _done = 0;
    });
    try {
      final rendered = <Uint8List>[];
      for (final frame in _frames) {
        final image = frame.image;
        if (image == null) {
          // A photo that would not decode is skipped rather than failing the
          // whole batch — the other nine are still what the author wanted.
          continue;
        }
        rendered.add(
          await renderCroppedPhoto(
            image: image,
            window: _windowFor(frame, constraints),
            transform: frame.transform,
          ),
        );
        if (!mounted) return;
        setState(() => _done = rendered.length);
      }
      if (!mounted) return;
      Navigator.of(context).pop(rendered);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось обрезать фото')));
    }
  }

  String get _applyLabel {
    if (!_saving) {
      return 'Готово';
    }
    return _frames.length > 1
        ? 'Готовим… $_done/${_frames.length}'
        : 'Готовим…';
  }

  @override
  Widget build(BuildContext context) {
    final frame = _current;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _frames.length > 1
              ? '${widget.title} · ${_index + 1}/${_frames.length}'
              : widget.title,
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
              onPressed: !_anyReady || _saving
                  ? null
                  : () => unawaited(_apply()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white24,
                textStyle: AppTypography.chip.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_applyLabel),
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
                  _constraints = constraints;
                  final image = frame.image;
                  if (frame.error != null) {
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
                  final window = _windowFor(frame, constraints);
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
                              transform: frame.transform,
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
            if (_frames.length > 1)
              _FilmStrip(
                frames: _frames,
                current: _index,
                onSelect: _saving ? null : _select,
              ),
            // Только поворот и сброс: «Готово» уехало в шапку. Отступ снизу
            // держит кнопки над системной полосой жестов, а не под ней.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _EditorAction(
                    icon: Icons.rotate_90_degrees_cw_rounded,
                    label: 'Повернуть',
                    onTap: frame.image == null || _saving
                        ? null
                        : () {
                            final image = frame.image!;
                            final constraints = _constraints;
                            if (constraints == null) return;
                            _rotate(
                              Size(
                                image.width.toDouble(),
                                image.height.toDouble(),
                              ),
                              _windowFor(frame, constraints),
                            );
                          },
                  ),
                  const SizedBox(width: 24),
                  _EditorAction(
                    icon: Icons.restart_alt_rounded,
                    label: 'Сбросить',
                    onTap: frame.image == null || _saving ? null : _reset,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip of picked photos along the bottom, for switching between them.
class _FilmStrip extends StatelessWidget {
  const _FilmStrip({
    required this.frames,
    required this.current,
    required this.onSelect,
  });

  final List<_Frame> frames;
  final int current;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('photo-editor-strip'),
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: frames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == current;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Фото ${index + 1}',
            child: GestureDetector(
              onTap: onSelect == null ? null : () => onSelect!(index),
              child: AnimatedContainer(
                key: ValueKey('photo-editor-thumb-$index'),
                duration: const Duration(milliseconds: 150),
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Opacity(
                    opacity: selected ? 1 : 0.55,
                    child: Image.file(
                      frames[index].source,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.white12,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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

/// Opens the editor for [sourcePaths] and writes each framed result to a temp
/// file.
///
/// Returns the paths of the cropped files, or null if the user backed out.
/// Call sites upload these instead of the raw picks, so what the author framed
/// is what everyone sees.
Future<List<String>?> cropPickedPhotos(
  BuildContext context, {
  required List<String> sourcePaths,
  PhotoCropShape shape = PhotoCropShape.free,
  String title = 'Кадрирование',
}) async {
  if (sourcePaths.isEmpty) {
    return null;
  }
  // rootNavigator: редактор должен накрыть весь экран. Без этого он
  // открывался внутри ветки-вкладки, и плавающая панель приложения со своей
  // белой подложкой оставалась поверх него (жалоба 2026-09-04).
  final rendered = await Navigator.of(context, rootNavigator: true)
      .push<List<Uint8List>>(
        MaterialPageRoute<List<Uint8List>>(
          fullscreenDialog: true,
          builder: (_) => PhotoEditorScreen(
            sources: [for (final path in sourcePaths) File(path)],
            shape: shape,
            title: title,
          ),
        ),
      );
  if (rendered == null || rendered.isEmpty) {
    return null;
  }
  final directory = await Directory.systemTemp.createTemp('crimeatrip-crop');
  final paths = <String>[];
  for (var index = 0; index < rendered.length; index++) {
    // .jpg, and not just for tidiness: the upload infers its content type
    // from the extension, and the API refuses anything that does not arrive
    // as an image.
    final target = File(
      '${directory.path}/crop-${DateTime.now().microsecondsSinceEpoch}-$index.jpg',
    );
    await target.writeAsBytes(rendered[index], flush: true);
    paths.add(target.path);
  }
  return paths;
}

/// Single-photo [cropPickedPhotos], for the avatar, cover and article flows.
Future<String?> cropPickedPhoto(
  BuildContext context, {
  required String sourcePath,
  PhotoCropShape shape = PhotoCropShape.free,
  String title = 'Кадрирование',
}) async {
  final paths = await cropPickedPhotos(
    context,
    sourcePaths: [sourcePath],
    shape: shape,
    title: title,
  );
  return paths == null || paths.isEmpty ? null : paths.first;
}
