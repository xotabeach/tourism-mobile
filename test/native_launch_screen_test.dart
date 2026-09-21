import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS launch screen is one navy-backed mark, not a theme pair', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final wordmarkContents =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/LaunchWordmark.imageset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final backgroundContents =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    expect(storyboard, contains('image="LaunchWordmark"'));
    expect(storyboard, contains('name="LaunchBackground"'));
    // One entry per scale and a single colour: the splash is deliberately the
    // same castle-on-night-blue in either system theme, so there are no
    // dark-appearance variants to keep in sync. The colour is the preloader's
    // first frame (#0A1630), so the hand-over to Flutter shows no flash.
    expect((wordmarkContents['images']! as List<Object?>), hasLength(3));
    expect((backgroundContents['colors']! as List<Object?>), hasLength(1));
    final background =
        ((backgroundContents['colors']! as List<Object?>).single
                as Map<String, Object?>)['color']!
            as Map<String, Object?>;
    final components = background['components']! as Map<String, Object?>;
    const navy = {'red': 10, 'green': 22, 'blue': 48};
    for (final channel in navy.entries) {
      expect(
        double.parse(components[channel.key]! as String) * 255,
        closeTo(channel.value, 1),
      );
    }
  });

  test('Android launch screen supplies day and night Rubik wordmarks', () {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/drawable-$density/launch_wordmark.png',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable-night-$density/launch_wordmark.png',
        ).existsSync(),
        isTrue,
      );
    }

    final launchDrawable = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final android12Style = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();

    expect(launchDrawable, contains('@color/launch_background'));
    expect(launchDrawable, contains('@drawable/launch_wordmark'));
    expect(android12Style, contains('windowSplashScreenAnimatedIcon'));
    // Android 12+ crops the icon to a circle, so it gets a smaller mark on a
    // 288 dp canvas instead of the full-size wordmark.
    expect(android12Style, contains('@drawable/launch_icon_v31'));
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/drawable-$density/launch_icon_v31.png',
        ).existsSync(),
        isTrue,
      );
    }
    for (final values in ['values', 'values-night']) {
      expect(
        File('android/app/src/main/res/$values/colors.xml').readAsStringSync(),
        contains('#0A1630'),
      );
    }
  });

  test('Android release manifest and signing policy are production-safe', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });
}
