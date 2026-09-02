import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

import '../support/test_overrides.dart';

const _goldenKey = ValueKey('golden-surface');
const _phoneSize = Size(393, 852);

/// Baselines are recorded on macOS, like the rest of the golden suite.
final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenFonts);

  testWidgets('golden route match — AI chat, as shipped today', (tester) async {
    await _pumpGolden(
      tester,
      const RouteMatchScreen(initialMode: RouteMatchMode.ai),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_match_ai.png'),
      skip: _skipPixelGoldens,
    );
  });
}

Future<void> _pumpGolden(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _phoneSize;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, appChild) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: TextScaler.noScaling,
            ),
            child: appChild!,
          );
        },
        home: RepaintBoundary(key: _goldenKey, child: child),
      ),
    ),
  );

  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in [
        AppImages.coastPineTwilight,
        AppImages.capeFiolentFog,
        AppImages.travelerPortrait,
        AppImages.welcomeSunset,
        AppImages.coastalBayHills,
      ])
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

Future<void> _loadGoldenFonts() async {
  final loader = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await loader.load();

  final materialIcons = File(
    '${_flutterSdkRoot().path}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  final materialLoader = FontLoader('MaterialIcons')
    ..addFont(materialIcons.readAsBytes().then(ByteData.sublistView));
  await materialLoader.load();
}

Directory _flutterSdkRoot() {
  var current = File(Platform.resolvedExecutable).parent;
  while (current.parent.path != current.path) {
    if (File('${current.path}/bin/flutter').existsSync()) {
      return current;
    }
    current = current.parent;
  }
  throw StateError('Unable to locate the active Flutter SDK');
}
