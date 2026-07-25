import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS launch screen uses adaptive CrimeTrip wordmark resources', () {
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
    expect((wordmarkContents['images']! as List<Object?>), hasLength(6));
    expect((backgroundContents['colors']! as List<Object?>), hasLength(2));
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
