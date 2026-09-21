import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/startup/splash_frames.dart';
import 'package:tourism_mobile/core/startup/splash_scene_layout.dart';
import 'package:tourism_mobile/core/startup/startup_gate.dart';

Future<ui.Image> _capture(WidgetTester tester, Widget child) async {
  const key = ValueKey('capture');
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 196, height: 426, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() => boundary.toImage()))!;
}

Future<List<int>> _pixels(WidgetTester tester, ui.Image image) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return data!.buffer.asUint8List();
}

void main() {
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
    // The welcome screen draws the flattened picture with this fit.
    final welcome = await _pixels(
      tester,
      await _capture(
        tester,
        const Image(
          image: SplashFrames.day,
          fit: BoxFit.cover,
          alignment: Alignment(-0.12, 0),
        ),
      ),
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
