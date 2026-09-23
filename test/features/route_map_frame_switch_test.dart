import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

const _config = AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  dataSource: AppDataSource.mock,
);

// Vorontsov palace, Livadia palace, Swallow's nest: the route from the bug.
const _stops = [
  RouteStop(
    id: 's1',
    position: 1,
    placeId: 'p1',
    placeName: 'Воронцовский дворец',
    placeSlug: 'vorontsov',
    lat: 44.4197,
    lng: 34.0556,
  ),
  RouteStop(
    id: 's2',
    position: 2,
    placeId: 'p2',
    placeName: 'Ливадийский дворец',
    placeSlug: 'livadia',
    lat: 44.4678,
    lng: 34.1436,
  ),
  RouteStop(
    id: 's3',
    position: 3,
    placeId: 'p3',
    placeName: 'Ласточкино гнездо',
    placeSlug: 'swallow',
    lat: 44.4307,
    lng: 34.1235,
  ),
];

const _leg = ActiveLeg(
  line: [(lat: 44.4678, lng: 34.1436), (lat: 44.4307, lng: 34.1235)],
  from: (lat: 44.4678, lng: 34.1436),
  to: (lat: 44.4307, lng: 34.1235),
);

/// A raster whose arrival the test decides: complete, fail or keep waiting.
class _Raster extends ImageProvider<_Raster> {
  _Raster(this.url);

  final String url;
  final completer = Completer<ImageInfo>();

  @override
  Future<_Raster> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Raster key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(completer.future);
}

Future<ui.Image> _pixel() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF88AA88),
  );
  return recorder.endRecording().toImage(1, 1);
}

void main() {
  final rasters = <String, _Raster>{};
  setUp(() {
    rasters.clear();
    debugRouteMapImage = (url) => rasters.putIfAbsent(url, () => _Raster(url));
  });
  tearDown(() => debugRouteMapImage = null);

  _Raster latest() => rasters.values.last;

  Future<void> arrive(WidgetTester tester, _Raster raster) async {
    final image = await tester.runAsync(_pixel);
    raster.completer.complete(ImageInfo(image: image!));
    await tester.pump();
    await tester.pump();
  }

  Offset pin(WidgetTester tester, int position) =>
      tester.getCenter(find.bySemanticsLabel(RegExp('^Точка $position,')));

  Future<ValueNotifier<bool>> pumpMap(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 700);
    addTearDown(tester.view.reset);
    final focus = ValueNotifier(false);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: focus,
            builder: (_, value, _) => RouteStaticMap(
              staticMapUrl: '/api/v1/maps/static/route/r1',
              stops: _stops,
              config: _config,
              height: 600,
              activeLeg: _leg,
              focusOnLeg: value,
              interactive: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await arrive(tester, latest());
    return focus;
  }

  testWidgets('pins stay on the old raster until the leg frame arrives', (
    tester,
  ) async {
    final focus = await pumpMap(tester);
    final whole = pin(tester, 2);

    focus.value = true;
    await tester.pump();
    await tester.pump();
    expect(rasters.length, 2, reason: 'the leg frame is requested');
    expect(
      pin(tester, 2),
      whole,
      reason: 'while it loads, pins keep matching the basemap on screen',
    );

    await arrive(tester, latest());
    expect(pin(tester, 2), isNot(whole), reason: 'now drawn for the leg frame');
  });

  testWidgets('a leg frame that fails keeps the whole route', (tester) async {
    final focus = await pumpMap(tester);
    final whole = pin(tester, 2);

    focus.value = true;
    await tester.pump();
    await tester.pump();
    latest().completer.completeError(Exception('502'));
    await tester.pump();
    await tester.pump();

    expect(pin(tester, 2), whole);
    expect(rasters.length, 2, reason: 'no new request after the failure');
  });

  testWidgets('a late leg frame does not replace the whole route', (
    tester,
  ) async {
    final focus = await pumpMap(tester);
    final whole = pin(tester, 2);

    focus.value = true;
    await tester.pump();
    await tester.pump();
    final leg = latest();
    focus.value = false;
    await tester.pump();
    await tester.pump();
    await arrive(tester, leg);

    expect(pin(tester, 2), whole);
  });

  testWidgets('switching the frame on full screen resets pinch zoom', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteStaticMap(
            staticMapUrl: '/api/v1/maps/static/route/r1',
            stops: _stops,
            config: _config,
            activeLeg: _leg,
          ),
        ),
      ),
    );
    await tester.pump();
    await arrive(tester, latest());
    await tester.tap(find.byType(RouteStaticMap));
    await tester.pumpAndSettle();
    await tester.pump();
    await arrive(tester, latest());

    final viewer = find.byType(InteractiveViewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    controller.value = Matrix4.identity()..scaleByDouble(3, 3, 1, 1);

    await tester.tap(find.text('Участок'));
    await tester.pump();
    expect(controller.value, Matrix4.identity());
  });
}
