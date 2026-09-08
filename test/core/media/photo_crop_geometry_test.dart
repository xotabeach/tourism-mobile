import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/media/photo_crop_geometry.dart';
import 'package:tourism_mobile/core/media/photo_editor_screen.dart';

/// The maths behind the photo editor. Kept as plain functions precisely so it
/// can be pinned here — the preview and the final render both use it, and if
/// they disagreed the upload would not match what the user framed.
void main() {
  _originalShapeGroup();
  _onePanGroup();
  group('rotation', () {
    test('a quarter turn swaps width and height', () {
      const image = Size(400, 300);
      expect(rotatedImageSize(image, 0), const Size(400, 300));
      expect(rotatedImageSize(image, 1), const Size(300, 400));
      expect(rotatedImageSize(image, 2), const Size(400, 300));
      expect(rotatedImageSize(image, 3), const Size(300, 400));
    });

    test('quarter turns wrap around and never go negative', () {
      const transform = PhotoCropTransform();
      expect(transform.copyWith(quarterTurns: 4).quarterTurns, 0);
      expect(transform.copyWith(quarterTurns: 5).quarterTurns, 1);
      expect(transform.copyWith(quarterTurns: -1).quarterTurns, 3);
    });
  });

  group('cover scale', () {
    test('a wide photo in a square window scales by height', () {
      // 400x200 into 300x300: height is the tighter side.
      expect(coverScale(const Size(400, 200), const Size(300, 300), 0), 1.5);
    });

    test('a tall photo in a square window scales by width', () {
      expect(coverScale(const Size(200, 400), const Size(300, 300), 0), 1.5);
    });

    test('rotation changes which side is tighter', () {
      const image = Size(400, 200);
      const window = Size(300, 300);
      // Rotated, the 200px side becomes the width, so it drives the scale.
      expect(coverScale(image, window, 1), 1.5);
    });

    test('a degenerate image does not divide by zero', () {
      expect(coverScale(Size.zero, const Size(300, 300), 0), 1);
    });
  });

  group('pan clamping', () {
    test('a photo cannot be dragged off the window', () {
      // 600x600 drawn into a 300x300 window leaves 150px of slack each way.
      final clamped = clampOffset(
        offset: const Offset(500, -500),
        image: const Size(600, 600),
        window: const Size(300, 300),
        scale: 1,
        quarterTurns: 0,
      );
      expect(clamped, const Offset(150, -150));
    });

    test('a photo exactly filling the window cannot move at all', () {
      final clamped = clampOffset(
        offset: const Offset(40, 40),
        image: const Size(300, 300),
        window: const Size(300, 300),
        scale: 1,
        quarterTurns: 0,
      );
      expect(clamped, Offset.zero);
    });

    test('pans within the slack are left alone', () {
      final clamped = clampOffset(
        offset: const Offset(20, -30),
        image: const Size(600, 600),
        window: const Size(300, 300),
        scale: 1,
        quarterTurns: 0,
      );
      expect(clamped, const Offset(20, -30));
    });
  });

  group('output size', () {
    test('small windows render at their own size', () {
      expect(croppedPixelSize(const Size(300, 300)), const Size(300, 300));
    });

    test('the crop keeps the resolution the photo actually has', () {
      // A 12MP photo behind a phone-sized crop window: one window pixel is
      // showing about eight source pixels, and rendering at the window's own
      // size threw seven of every eight away.
      const window = Size(360, 360);
      const photo = Size(4032, 3024);
      final resolution = sourcePixelsPerWindowPixel(
        image: photo,
        window: window,
        transform: const PhotoCropTransform(),
      );
      expect(resolution, closeTo(3024 / 360, 0.001));
      expect(
        croppedPixelSize(window, resolution: resolution, maxSide: 4096),
        const Size(3024, 3024),
      );
      // The default cap still applies — this is resolution recovered up to
      // the upload ceiling, not an uncapped one.
      expect(croppedPixelSize(window, resolution: resolution), const Size(2048, 2048));
    });

    test('a photo smaller than the window is not invented into one', () {
      final resolution = sourcePixelsPerWindowPixel(
        image: const Size(120, 90),
        window: const Size(360, 360),
        transform: const PhotoCropTransform(),
      );
      expect(resolution, 1);
    });

    test('zooming in spends resolution, so the cap still applies', () {
      const window = Size(360, 360);
      const photo = Size(4032, 3024);
      final resolution = sourcePixelsPerWindowPixel(
        image: photo,
        window: window,
        transform: const PhotoCropTransform(scale: 4),
      );
      // Four times the zoom is a quarter of the source pixels per window
      // pixel — the framed area really is that much smaller.
      expect(resolution, closeTo(3024 / 360 / 4, 0.001));
      expect(
        croppedPixelSize(window, resolution: resolution, maxSide: 2048),
        const Size(756, 756),
      );
    });

    test('a big source is still capped', () {
      final resolution = sourcePixelsPerWindowPixel(
        image: const Size(8000, 6000),
        window: const Size(360, 360),
        transform: const PhotoCropTransform(),
      );
      final size = croppedPixelSize(
        const Size(360, 360),
        resolution: resolution,
        maxSide: 2048,
      );
      expect(size, const Size(2048, 2048));
    });

    test('a huge window is capped without distorting the aspect', () {
      final size = croppedPixelSize(const Size(4000, 2000), maxSide: 2048);
      expect(size.width, 2048);
      expect(size.height, 1024);
    });

    test('a zero window still produces a drawable size', () {
      expect(croppedPixelSize(Size.zero), const Size(1, 1));
    });
  });
}

/// One finger drags the photo inside the frame; two fingers zoom. The editor
/// feeds both through the same scale gesture (a single-pointer drag reports
/// `scale == 1` and a moving focal point), so what decides whether a drag
/// does anything is the slack these helpers leave.
void _onePanGroup() {
  group('dragging the photo', () {
    test('a tall photo in a wide frame can be dragged up and down', () {
      const photo = Size(400, 1200);
      const window = Size(360, 202); // 16:9
      final scale = coverScale(photo, window, 0);

      final dragged = clampOffset(
        offset: const Offset(0, -120),
        image: photo,
        window: window,
        scale: scale,
        quarterTurns: 0,
      );
      expect(dragged.dy, -120, reason: 'the drag is inside the slack');
      expect(dragged.dx, 0, reason: 'nothing to pan sideways here');

      // Past the edge it stops rather than exposing a transparent gap.
      final overshot = clampOffset(
        offset: const Offset(0, -100000),
        image: photo,
        window: window,
        scale: scale,
        quarterTurns: 0,
      );
      expect(overshot.dy, greaterThan(-100000));
      expect(overshot.dy, lessThan(0));
    });

    test('zooming in gives a photo that exactly fits room to move', () {
      const photo = Size(1200, 900);
      const window = Size(360, 270); // same aspect: no slack at 1x
      final fitted = coverScale(photo, window, 0);
      expect(
        clampOffset(
          offset: const Offset(40, 40),
          image: photo,
          window: window,
          scale: fitted,
          quarterTurns: 0,
        ),
        Offset.zero,
      );

      expect(
        clampOffset(
          offset: const Offset(40, 40),
          image: photo,
          window: window,
          scale: fitted * 2,
          quarterTurns: 0,
        ),
        const Offset(40, 40),
      );
    });
  });
}

void _originalShapeGroup() {
  group('PhotoCropShape.original', () {
    test('has no fixed aspect, so the window can follow the photo', () {
      expect(PhotoCropShape.original.aspectRatio, isNull);
      expect(PhotoCropShape.original.circular, isFalse);
      // The shapes that do frame to a fixed window keep theirs.
      expect(PhotoCropShape.wide.aspectRatio, closeTo(16 / 9, 1e-9));
      expect(PhotoCropShape.avatar.aspectRatio, 1);
    });

    test('a window matching the photo crops nothing away', () {
      // What the editor does for `original`: window aspect = photo aspect.
      // coverScale then lands on an exact fit instead of overflowing, which
      // is what "no crop" means in practice.
      const portrait = Size(1080, 1920);
      final window = Size(360, 360 * portrait.height / portrait.width);
      final scale = coverScale(portrait, window, 0);
      expect(portrait.width * scale, closeTo(window.width, 0.001));
      expect(portrait.height * scale, closeTo(window.height, 0.001));
    });

    test('the same holds once the photo is rotated a quarter turn', () {
      const portrait = Size(1080, 1920);
      final rotated = rotatedImageSize(portrait, 1);
      final window = Size(360, 360 * rotated.height / rotated.width);
      final scale = coverScale(portrait, window, 1);
      expect(rotated.width * scale, closeTo(window.width, 0.001));
      expect(rotated.height * scale, closeTo(window.height, 0.001));
    });
  });
}
