import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_checkout_screen.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_travel_plus_screen.dart';

import '../support/test_overrides.dart';

const _surfaceKey = ValueKey('travel-plus-golden-surface');
const _referencePhysicalSize = Size(708, 2048);

final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('golden Travel Plus inactive content', (tester) async {
    await _pumpReferenceFrame(tester, const SettingsTravelPlusScreen());

    await expectLater(
      find.byKey(_surfaceKey),
      matchesGoldenFile('goldens/travel_plus_inactive.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden Travel Plus checkout content', (tester) async {
    await _pumpReferenceFrame(tester, const SettingsTravelPlusCheckoutScreen());

    await expectLater(
      find.byKey(_surfaceKey),
      matchesGoldenFile('goldens/travel_plus_checkout.png'),
    );
  }, skip: _skipPixelGoldens);
}

Future<void> _pumpReferenceFrame(WidgetTester tester, Widget child) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = _referencePhysicalSize;
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(
        onboardingCompleted: true,
        displayName: 'Никита Можаров',
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
        builder: (context, appChild) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: TextScaler.noScaling,
            disableAnimations: true,
          ),
          child: appChild!,
        ),
        home: RepaintBoundary(
          key: _surfaceKey,
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
  final rubik = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await rubik.load();

  final materialIcons = File(
    '${_flutterSdkRoot().path}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  final icons = FontLoader('MaterialIcons')
    ..addFont(materialIcons.readAsBytes().then(ByteData.sublistView));
  await icons.load();
}

Directory _flutterSdkRoot() {
  var current = File(Platform.resolvedExecutable).parent;
  while (current.parent.path != current.path) {
    if (File('${current.path}/bin/flutter').existsSync()) return current;
    current = current.parent;
  }
  throw StateError('Unable to locate the active Flutter SDK');
}
