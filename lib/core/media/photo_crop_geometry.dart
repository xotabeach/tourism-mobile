import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Geometry for the photo editor, kept as plain functions so the maths can be
/// tested without rendering anything.
///
/// The editor shows a fixed crop window and moves the *photo* behind it:
/// the user pans, pinches and rotates in 90° steps, and whatever is inside
/// the window is what gets uploaded. Everything below describes that one
/// arrangement, and the same numbers drive both the on-screen preview and
/// the final render — if they disagreed, the result would not match what the
/// user framed.
@immutable
class PhotoCropTransform {
  const PhotoCropTransform({
    this.scale = 1,
    this.offset = Offset.zero,
    this.quarterTurns = 0,
  });

  /// User zoom, on top of the base scale that makes the photo cover the window.
  final double scale;

  /// Pan, in window pixels.
  final Offset offset;

  /// Rotation in 90° steps, always normalised to 0..3.
  final int quarterTurns;

  PhotoCropTransform copyWith({
    double? scale,
    Offset? offset,
    int? quarterTurns,
  }) {
    return PhotoCropTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      quarterTurns: ((quarterTurns ?? this.quarterTurns) % 4 + 4) % 4,
    );
  }

  bool get isSideways => quarterTurns.isOdd;
}

/// Size of the photo after rotation — width and height swap on a quarter turn.
Size rotatedImageSize(Size image, int quarterTurns) {
  return quarterTurns.isOdd
      ? Size(image.height, image.width)
      : Size(image.width, image.height);
}

/// Scale at which the rotated photo just covers the crop window.
///
/// Cover rather than contain: a crop window showing empty bars would let
/// someone upload an avatar that is mostly background.
double coverScale(Size image, Size window, int quarterTurns) {
  final rotated = rotatedImageSize(image, quarterTurns);
  if (rotated.width <= 0 || rotated.height <= 0) {
    return 1;
  }
  return math.max(window.width / rotated.width, window.height / rotated.height);
}

/// Clamps pan so the photo can never be dragged off the crop window, leaving
/// a transparent gap in the upload.
Offset clampOffset({
  required Offset offset,
  required Size image,
  required Size window,
  required double scale,
  required int quarterTurns,
}) {
  final rotated = rotatedImageSize(image, quarterTurns);
  final drawn = Size(rotated.width * scale, rotated.height * scale);
  // Slack is how far the photo may travel before its edge enters the window.
  final slackX = math.max(0.0, (drawn.width - window.width) / 2);
  final slackY = math.max(0.0, (drawn.height - window.height) / 2);
  return Offset(
    offset.dx.clamp(-slackX, slackX),
    offset.dy.clamp(-slackY, slackY),
  );
}

/// Output pixel size for a crop window, capped so a huge photo does not turn
/// into a huge upload.
Size croppedPixelSize(Size window, {double maxSide = 2048}) {
  final longest = math.max(window.width, window.height);
  if (longest <= 0) {
    return const Size(1, 1);
  }
  final factor = longest > maxSide ? maxSide / longest : 1.0;
  return Size(
    math.max(1, (window.width * factor).roundToDouble()),
    math.max(1, (window.height * factor).roundToDouble()),
  );
}

/// Draws the framed area at upload resolution and returns it as PNG bytes.
///
/// Deliberately the same arithmetic the preview painter uses, one scale
/// factor apart: the crop window becomes the canvas, so what the user framed
/// is exactly what is written out. Anything computed differently here would
/// hand back a photo that does not match what they saw.
Future<Uint8List> renderCroppedPhoto({
  required ui.Image image,
  required Size window,
  required PhotoCropTransform transform,
  double maxSide = 2048,
}) async {
  final output = croppedPixelSize(window, maxSide: maxSide);
  final ratio = output.width / window.width;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, output.width, output.height),
  );
  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final scale =
      coverScale(imageSize, window, transform.quarterTurns) *
      transform.scale *
      ratio;

  canvas
    ..translate(output.width / 2, output.height / 2)
    ..translate(transform.offset.dx * ratio, transform.offset.dy * ratio)
    ..rotate(transform.quarterTurns * (math.pi / 2))
    ..scale(scale);
  canvas.drawImage(
    image,
    Offset(-imageSize.width / 2, -imageSize.height / 2),
    Paint()..filterQuality = FilterQuality.high,
  );

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(
    output.width.round(),
    output.height.round(),
  );
  picture.dispose();
  try {
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Пустой результат кадрирования');
    }
    return data.buffer.asUint8List();
  } finally {
    rendered.dispose();
  }
}
