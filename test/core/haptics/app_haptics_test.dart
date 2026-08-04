import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/haptics/app_haptics.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppHaptics.setEnabled(true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('device haptic preference is restored and persisted locally', () async {
    final storage = MemorySecureStorage();
    await storage.write(
      key: SecureStorageKeys.appHapticsEnabled,
      value: 'false',
    );
    final container = ProviderContainer(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    container.listen<bool>(appHapticsEnabledProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appHapticsEnabledProvider), isFalse);

    await container.read(appHapticsEnabledProvider.notifier).setEnabled(true);
    expect(
      await storage.read(key: SecureStorageKeys.appHapticsEnabled),
      'true',
    );
  });

  test('disabled gateway suppresses platform vibration calls', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });

    AppHaptics.setEnabled(false);
    await AppHaptics.selectionClick();
    await AppHaptics.mediumImpact();
    expect(calls, isEmpty);

    AppHaptics.setEnabled(true);
    await AppHaptics.selectionClick();
    expect(calls, hasLength(1));
  });
}
