import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/application/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unknown id falls back to the standard icon', () {
    // The platform is asked which icon is live; a value this build does not
    // know about (an alias left over from a downgrade) must not break the
    // settings screen.
    expect(AppIconVariant.fromId('sunset'), AppIconVariant.sunset);
    expect(AppIconVariant.fromId('does-not-exist'), AppIconVariant.standard);
    expect(AppIconVariant.fromId(null), AppIconVariant.standard);
  });

  test('every variant ships a preview asset', () {
    // Previews come from the bundle: neither platform lets an app read its
    // own alternate icons back as images.
    for (final variant in AppIconVariant.values) {
      expect(
        File(variant.previewAsset).existsSync(),
        isTrue,
        reason: variant.previewAsset,
      );
    }
  });

  test('a platform failure comes back as a message, not an exception', () async {
    const channel = MethodChannel('test/icons');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unsupported', message: 'Нельзя тут');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    const service = AppIconService(channel);
    expect(await service.apply(AppIconVariant.sea), 'Нельзя тут');
    // Reading falls back rather than propagating — the screen still renders.
    expect(await service.current(), AppIconVariant.standard);
  });

  test('the Android manifest keeps exactly one launcher alias enabled', () {
    // With every alias disabled the app would vanish from the launcher and
    // there would be no way back in, so the default one ships enabled.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(RegExp(r'android:enabled="true"').allMatches(manifest).length, 1);
    for (final variant in AppIconVariant.values) {
      if (variant == AppIconVariant.standard) continue;
      expect(
        manifest,
        contains('@mipmap/ic_launcher_${variant.id}'),
        reason: variant.id,
      );
    }
  });

  test('every Android density ships every alternate icon', () {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final variant in AppIconVariant.values) {
        final name = variant == AppIconVariant.standard
            ? 'ic_launcher'
            : 'ic_launcher_${variant.id}';
        expect(
          File('android/app/src/main/res/mipmap-$density/$name.png').existsSync(),
          isTrue,
          reason: '$density/$name',
        );
      }
    }
  });

  test('iOS ships each alternate icon as its own asset-catalog set', () {
    // The first attempt declared them in Info.plist as loose files under
    // AltIcons/ — which iOS ignores twice over: alternate icon names cannot
    // contain a path, and the files were never added to the Xcode project,
    // so they never reached the bundle. The result on device was Apple's
    // placeholder grid (reported 2026-09-04).
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      project,
      contains('ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES'),
      reason: 'без этого в бандл попадёт только основная иконка',
    );

    expect(
      File('ios/Runner/AltIcons').existsSync(),
      isFalse,
      reason: 'файловый способ заменён каталогом',
    );

    for (final variant in AppIconVariant.values) {
      if (variant == AppIconVariant.standard) continue;
      // The set is named exactly as the id passed to setAlternateIconName.
      final set = Directory('ios/Runner/Assets.xcassets/${variant.id}.appiconset');
      expect(set.existsSync(), isTrue, reason: variant.id);
      final contents = File('${set.path}/Contents.json');
      expect(contents.existsSync(), isTrue, reason: variant.id);
      // 60pt@2x/@3x are what the home screen actually draws.
      for (final file in ['Icon-60@2x.png', 'Icon-60@3x.png']) {
        expect(
          File('${set.path}/$file').existsSync(),
          isTrue,
          reason: '${variant.id}/$file',
        );
      }
    }
  });
}
