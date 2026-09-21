import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:tourism_mobile/core/startup/splash_scene_layout.dart';

/// Assets of the preloader scene. The scene is built from the designer's
/// layers (one consistent picture); the day part of it is also flattened into
/// [day] for the welcome screen and for reduce-motion.
abstract final class SplashFrames {
  /// The finished day scene without the logo.
  static const day = AssetImage('assets/splash/scene_day.jpg');

  static const daySkyColor = Color(0xFF1F6CCC);

  /// The day sky: a smooth gradient, shipped as a thin strip.
  static const skyDay = AssetImage('assets/splash/scene/sky_day.png');

  static AssetImage layer(String name) =>
      AssetImage('assets/splash/scene/$name.png');

  static ImageStream? _dayStream;
  static ImageStreamListener? _dayListener;

  /// Holds the «day» frame for the life of the process. A listener on the
  /// stream keeps the decoded image in the framework's live-image set, so the
  /// bounded image cache cannot evict it while covers pile in — the welcome
  /// screen (also after signing out) reuses it without decoding again.
  static void keepDayAlive() {
    if (_dayStream != null) {
      return;
    }
    final stream = day.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((_, _) {}, onError: (_, _) {});
    stream.addListener(listener);
    _dayStream = stream;
    _dayListener = listener;
  }

  /// Test hook: forget the held stream.
  static void releaseDay() {
    final stream = _dayStream;
    final listener = _dayListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _dayStream = null;
    _dayListener = null;
  }
}

/// Preserve the whole coastline on tall phones; extend the clear sky above
/// it instead of cropping out the sun or the people at either edge.
class SplashDayBackdrop extends StatelessWidget {
  const SplashDayBackdrop({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SplashFrames.daySkyColor,
    child: Image(
      image: SplashFrames.day,
      fit: BoxFit.fitWidth,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: SplashFrames.daySkyColor),
    ),
  );
}

/// A decoded frame plus the listener that keeps it alive until [dispose].
class LoadedFrame {
  LoadedFrame._(this._info, this._stream, this._listener);

  final ImageInfo _info;
  final ImageStream _stream;
  final ImageStreamListener _listener;

  ui.Image get image => _info.image;

  void dispose() {
    _stream.removeListener(_listener);
    _info.dispose();
  }

  /// Null when the asset is missing or cannot be decoded: the gate then draws
  /// its plain navy background instead of failing.
  static Future<LoadedFrame?> load(ImageProvider provider) {
    final completer = Completer<LoadedFrame?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(LoadedFrame._(info.clone(), stream, listener));
        }
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// All scene layers decoded, or null if any failed (then the gate falls back
/// to the flattened [SplashFrames.day] picture).
class LoadedScene {
  LoadedScene._(this.sky, this.layers);

  final LoadedFrame sky;

  /// Same order as [splashSceneLayers].
  final List<LoadedFrame> layers;

  static Future<LoadedScene?> load() async {
    final loaded = await Future.wait([
      LoadedFrame.load(SplashFrames.skyDay),
      for (final layer in splashSceneLayers)
        LoadedFrame.load(SplashFrames.layer(layer.name)),
    ]);
    if (loaded.any((frame) => frame == null)) {
      for (final frame in loaded) {
        frame?.dispose();
      }
      return null;
    }
    final frames = loaded.cast<LoadedFrame>();
    return LoadedScene._(frames.first, frames.sublist(1));
  }

  void dispose() {
    sky.dispose();
    for (final layer in layers) {
      layer.dispose();
    }
    for (final layer in splashSceneLayers) {
      PaintingBinding.instance.imageCache.evict(SplashFrames.layer(layer.name));
    }
    PaintingBinding.instance.imageCache.evict(SplashFrames.skyDay);
  }
}
