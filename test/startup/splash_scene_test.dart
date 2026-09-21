import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/startup/krymtrip_logo.dart';
import 'package:tourism_mobile/core/startup/splash_frames.dart';
import 'package:tourism_mobile/core/startup/splash_scene_layout.dart';
import 'package:tourism_mobile/core/startup/startup_gate.dart';

Future<ui.Image> _capture(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(196, 426),
}) async {
  const key = ValueKey('capture');
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(boundary.toImage))!;
}

Future<List<int>> _pixels(WidgetTester tester, ui.Image image) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('sunrise phases stay continuous and brighten progressively', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(392, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(SplashFrames.day, context);
      await precacheImage(SplashFrames.skyDay, context);
      for (final layer in splashSceneLayers) {
        await precacheImage(SplashFrames.layer(layer.name), context);
      }
    });

    // Optional review frames come from the actual Flutter painter, including
    // the production logo, rather than a second implementation of the scene.
    final output = Platform.environment['SPLASH_PREVIEW_DIR'];
    final steps = output == null ? 20 : 90;
    List<int>? previous;
    var previousBrightness = 0.0;
    for (var i = 0; i <= steps; i++) {
      final progress = i / steps;
      final frame = await _capture(
        tester,
        Stack(
          fit: StackFit.expand,
          children: [
            SplashScenePreview(progress: progress),
            Center(
              child: KrymtripLogo(
                width: output == null ? startupLogoWidth / 2 : startupLogoWidth,
              ),
            ),
          ],
        ),
        size: output == null ? const Size(196, 426) : const Size(392, 852),
      );
      final pixels = await _pixels(tester, frame);
      var brightness = 0.0;
      var delta = 0;
      for (var p = 0; p < pixels.length; p += 4) {
        brightness +=
            pixels[p] * 0.2126 +
            pixels[p + 1] * 0.7152 +
            pixels[p + 2] * 0.0722;
        if (previous != null) {
          for (var c = 0; c < 3; c++) {
            delta += (pixels[p + c] - previous[p + c]).abs();
          }
        }
      }
      brightness /= pixels.length / 4;
      expect(
        brightness,
        greaterThanOrEqualTo(previousBrightness - 0.1),
        reason: 'light must not flash darker at $progress',
      );
      expect(
        delta / pixels.length,
        lessThan(12),
        reason: 'abrupt phase transition at $progress',
      );
      previousBrightness = brightness;
      previous = pixels;
      if (output != null) {
        await tester.runAsync(() async {
          final png = await frame.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '$output/frame_${i.toString().padLeft(3, '0')}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        });
      }
      frame.dispose();
    }
  });

  testWidgets('no line where the scene meets the sky above it', (tester) async {
    // A tall phone: the scene is fitted to the width, so there is sky above
    // it. Its top edge used to show as a line mid-sunrise.
    const size = Size(393, 852);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(SplashFrames.day, context);
      await precacheImage(SplashFrames.skyDay, context);
      for (final layer in splashSceneLayers) {
        await precacheImage(SplashFrames.layer(layer.name), context);
      }
    });
    final edge =
        (size.height - splashSceneHeight * size.width / splashSceneWidth)
            .round();
    int channel(List<int> pixels, int row, int c) =>
        pixels[(row * size.width.toInt() + size.width ~/ 2) * 4 + c];

    for (final progress in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
      final frame = await _capture(
        tester,
        SplashScenePreview(progress: progress),
        size: size,
      );
      final pixels = await _pixels(tester, frame);
      // Neighbouring rows across the edge: the old line was one or two
      // rows darker than the sky on both sides of it.
      for (var row = edge - 5; row < edge + 5; row++) {
        for (var c = 0; c < 3; c++) {
          expect(
            (channel(pixels, row + 1, c) - channel(pixels, row, c)).abs(),
            lessThanOrEqualTo(3),
            reason: 'line at the scene top at $progress, row $row',
          );
        }
      }
      frame.dispose();
    }
  });

  test('every scene layer is bundled', () {
    expect(File('assets/splash/scene/sky_day.png').existsSync(), isTrue);
    expect(File('assets/splash/scene_day.jpg').existsSync(), isTrue);
    for (final layer in splashSceneLayers) {
      expect(
        File('assets/splash/scene/${layer.name}.png').existsSync(),
        isTrue,
        reason: layer.name,
      );
    }
  });

  testWidgets('the last sunrise frame is the welcome background, so the '
      'hand-over does not jump', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(SplashFrames.day, context);
      await precacheImage(SplashFrames.skyDay, context);
      for (final layer in splashSceneLayers) {
        await precacheImage(SplashFrames.layer(layer.name), context);
      }
    });

    final scene = await _pixels(
      tester,
      await _capture(tester, const SplashScenePreview(progress: 1)),
    );
    // Use the same widget as Welcome so fitting and sky extension are checked.
    final welcome = await _pixels(
      tester,
      await _capture(tester, const SplashDayBackdrop()),
    );

    var diff = 0;
    for (var i = 0; i < scene.length; i++) {
      diff += (scene[i] - welcome[i]).abs();
    }
    final meanPerChannel = diff / scene.length;
    // Only resampling and JPEG noise: a different picture is ~40+.
    expect(meanPerChannel, lessThan(6));

    final night = await _pixels(
      tester,
      await _capture(tester, const SplashScenePreview(progress: 0)),
    );
    var nightDiff = 0;
    for (var i = 0; i < night.length; i++) {
      nightDiff += (night[i] - welcome[i]).abs();
    }
    // And the night really is a different light, not the same frame.
    expect(nightDiff / night.length, greaterThan(40));
  });
}
