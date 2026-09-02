import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/my_routes/presentation/widgets/section_dropdown.dart';

const _goldenKey = ValueKey('golden-surface');

final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

const _options = [
  SectionOption(
    value: MyRoutesTab.favorites,
    label: 'Маршруты',
    icon: Icons.route_rounded,
    count: 6,
  ),
  SectionOption(
    value: MyRoutesTab.places,
    label: 'Места',
    icon: Icons.place_rounded,
    count: 12,
  ),
  SectionOption(
    value: MyRoutesTab.articles,
    label: 'Статьи',
    icon: Icons.article_rounded,
    count: 3,
  ),
  SectionOption(
    value: MyRoutesTab.subscriptions,
    label: 'Подписки',
    icon: Icons.people_alt_rounded,
    count: 4,
  ),
  SectionOption(
    value: MyRoutesTab.history,
    label: 'История',
    icon: Icons.history_rounded,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenFonts);

  testWidgets('golden section dropdown closed', (tester) async {
    await _pump(tester, size: const Size(393, 120));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/section_dropdown_closed.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden section dropdown open', (tester) async {
    await _pump(tester, size: const Size(393, 420));
    await tester.tap(find.byKey(const ValueKey('section-dropdown-header')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/section_dropdown_open.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('picking a section closes the panel and reports the choice', (
    tester,
  ) async {
    MyRoutesTab? picked;
    await _pump(
      tester,
      size: const Size(393, 420),
      onChanged: (tab) => picked = tab,
    );

    await tester.tap(find.byKey(const ValueKey('section-dropdown-header')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('section-dropdown-panel')), findsOneWidget);

    await tester.tap(find.text('Статьи'));
    await tester.pumpAndSettle();

    expect(picked, MyRoutesTab.articles);
    // Collapsed again — and gone from the tree, not merely invisible.
    expect(find.byKey(const ValueKey('section-dropdown-panel')), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  ValueChanged<MyRoutesTab>? onChanged,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: _goldenKey,
        child: ColoredBox(
          color: AppColors.pageSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: SectionDropdown<MyRoutesTab>(
                options: _options,
                selected: MyRoutesTab.favorites,
                onChanged: onChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
