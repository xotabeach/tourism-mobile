import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The four backdrops of the preloader (night → dusk → sunrise → day). The
/// final «day» frame is also the welcome screen's background.
abstract final class SplashFrames {
  static const night = AssetImage('assets/splash/bg_1_night.jpg');
  static const dusk = AssetImage('assets/splash/bg_2_dusk.jpg');
  static const sunrise = AssetImage('assets/splash/bg_3_sunrise.jpg');
  static const day = AssetImage('assets/splash/bg_4_day.jpg');

  static const all = <ImageProvider>[night, dusk, sunrise, day];

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
