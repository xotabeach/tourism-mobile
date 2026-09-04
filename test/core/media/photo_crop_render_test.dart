import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/media/photo_crop_geometry.dart';

/// The render path, exercised on a real image.
///
/// It is a widget test only because decoding and rasterising need the engine
/// binding; there is no widget here. The screen calls exactly this function,
/// so what is pinned below is what gets uploaded.
Future<ui.Image> _sample({int width = 60, int height = 40}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF2997FF),
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  testWidgets('a square window yields a square photo, whatever the source', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = await _sample();
      addTearDown(image.dispose);

      final bytes = await renderCroppedPhoto(
        image: image,
        window: const Size(300, 300),
        transform: const PhotoCropTransform(),
      );

      final decoded = await decodeImageFromList(bytes);
      addTearDown(decoded.dispose);
      expect(decoded.width, 300);
      expect(decoded.height, 300);
    });
  });

  testWidgets('a wide window keeps its aspect', (tester) async {
    await tester.runAsync(() async {
      final image = await _sample(width: 400, height: 400);
      addTearDown(image.dispose);

      final bytes = await renderCroppedPhoto(
        image: image,
        window: const Size(320, 180),
        transform: const PhotoCropTransform(),
      );

      final decoded = await decodeImageFromList(bytes);
      addTearDown(decoded.dispose);
      expect(decoded.width, 320);
      expect(decoded.height, 180);
    });
  });

  testWidgets('a huge window is capped, so an upload cannot balloon', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = await _sample(width: 200, height: 200);
      addTearDown(image.dispose);

      final bytes = await renderCroppedPhoto(
        image: image,
        window: const Size(4000, 2000),
        transform: const PhotoCropTransform(),
        maxSide: 512,
      );

      final decoded = await decodeImageFromList(bytes);
      addTearDown(decoded.dispose);
      expect(decoded.width, 512);
      expect(decoded.height, 256);
    });
  });

  testWidgets('a rotated crop is not the same picture as an unrotated one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Asymmetric source, so a quarter turn has to change the pixels.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 80, 80),
        Paint()..color = const Color(0xFF2997FF),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 80, 20),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final image = await recorder.endRecording().toImage(80, 80);
      addTearDown(image.dispose);

      final straight = await renderCroppedPhoto(
        image: image,
        window: const Size(100, 100),
        transform: const PhotoCropTransform(),
      );
      final turned = await renderCroppedPhoto(
        image: image,
        window: const Size(100, 100),
        transform: const PhotoCropTransform(quarterTurns: 1),
      );

      expect(straight, isNot(equals(turned)));
    });
  });
}
