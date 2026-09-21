import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_account_screens.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets('log out stands apart: red mark and the design wording', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1400);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(home: SettingsAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выйти из профиля'), findsOneWidget);
    expect(
      find.text('Профиль будет забыт на данном устройстве'),
      findsOneWidget,
    );
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.any(
        (image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName ==
                AppIconography.settingsLogout,
      ),
      isTrue,
    );
  });
}
