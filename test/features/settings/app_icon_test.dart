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

  test('iOS declares its alternate icons and ships the files', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('CFBundleAlternateIcons'));
    for (final variant in AppIconVariant.values) {
      if (variant == AppIconVariant.standard) continue;
      expect(plist, contains('AltIcons/AppIcon-${variant.id}'));
      for (final scale in ['@2x', '@3x']) {
        expect(
          File('ios/Runner/AltIcons/AppIcon-${variant.id}$scale.png').existsSync(),
          isTrue,
          reason: '${variant.id}$scale',
        );
      }
    }
  });
}
