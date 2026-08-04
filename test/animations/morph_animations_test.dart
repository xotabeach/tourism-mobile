import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

const _navSurfaceKey = ValueKey('compose-motion-surface');
const _modeSurfaceKey = ValueKey('mode-motion-surface');
const _durationSurfaceKey = ValueKey('duration-motion-surface');

final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRubik);

  testWidgets('compose actions morph out of the center and reverse cleanly', (
    tester,
  ) async {
    await _pumpNav(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('app-shell-bottom-bar'))).height,
      58,
    );

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));

    final midHeight = tester
        .getSize(find.byKey(const ValueKey('app-shell-bottom-bar')))
        .height;
    expect(midHeight, inExclusiveRange(58, 120));
    expect(find.byKey(const ValueKey('nav-compose-actions')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nav-compose-action-Опубликовать')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('nav-compose-action-Подобрать')),
      findsOneWidget,
    );
    final leftOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('nav-compose-label-Опубликовать')),
    );
    final rightOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('nav-compose-label-Подобрать')),
    );
    expect(leftOpacity.opacity, inExclusiveRange(0, 1));
    expect(rightOpacity.opacity, inExclusiveRange(0, 1));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-shell-bottom-bar'))).height,
      120,
    );
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('nav-compose-action-Опубликовать')),
          )
          .right,
      lessThan(
        tester
            .getRect(find.byKey(const ValueKey('nav-compose-action-Подобрать')))
            .left,
      ),
    );

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-compose-actions')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('app-shell-bottom-bar'))).height,
      58,
    );
  });

  testWidgets('mode selector morphs widths without replacing its gradient', (
    tester,
  ) async {
    await _pumpMode(tester);
    final initialParams = tester
        .getSize(find.byKey(const ValueKey('route-mode-params')))
        .width;
    final initialAi = tester
        .getSize(find.byKey(const ValueKey('route-mode-ai')))
        .width;
    expect(initialParams, greaterThan(initialAi));

    await tester.tap(find.bySemanticsLabel('Режим подбор с ИИ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final earlyAi = tester
        .getSize(find.byKey(const ValueKey('route-mode-ai')))
        .width;
    expect(earlyAi, greaterThan(initialAi + 1));
    await tester.pump(const Duration(milliseconds: 210));
    final midParams = tester
        .getSize(find.byKey(const ValueKey('route-mode-params')))
        .width;
    final midAi = tester
        .getSize(find.byKey(const ValueKey('route-mode-ai')))
        .width;
    expect(midParams, lessThan(initialParams));
    expect(midAi, greaterThan(initialAi));
    expect(
      find.byKey(const ValueKey('route-mode-switch-paint')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    final finalParams = tester
        .getSize(find.byKey(const ValueKey('route-mode-params')))
        .width;
    final finalAi = tester
        .getSize(find.byKey(const ValueKey('route-mode-ai')))
        .width;
    expect(finalParams, lessThan(finalAi));
    expect(finalParams, lessThan(midParams));
    expect(finalAi, greaterThan(midAi));

    await tester.tap(find.bySemanticsLabel('Режим по параметрам'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final earlyParams = tester
        .getSize(find.byKey(const ValueKey('route-mode-params')))
        .width;
    expect(earlyParams, greaterThan(finalParams + 1));
  });

  testWidgets('center branch folds both groups before parking on the right', (
    tester,
  ) async {
    await _pumpCenterCompactNav(tester);
    final compact = find.byKey(const ValueKey('expand-detail-navigation'));
    expect(compact, findsOneWidget);
    expect(tester.getCenter(compact).dx, greaterThan(330));

    await tester.tap(compact);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(compact, findsNothing);
    expect(find.bySemanticsLabel('Главная'), findsOneWidget);
    expect(find.bySemanticsLabel('Профиль'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 900));
    expect(compact, findsOneWidget);
    expect(tester.getCenter(compact).dx, greaterThan(330));
    expect(tester.takeException(), isNull);
  });

  testWidgets('golden compose liquid morph midpoint', (tester) async {
    await _pumpNav(tester);
    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await expectLater(
      find.byKey(_navSurfaceKey),
      matchesGoldenFile('../golden/goldens/nav_compose_morph_mid.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden mode selector morph midpoint', (tester) async {
    await _pumpMode(tester);
    await tester.tap(find.bySemanticsLabel('Режим подбор с ИИ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    await expectLater(
      find.byKey(_modeSurfaceKey),
      matchesGoldenFile('../golden/goldens/mode_switch_morph_mid.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('duration selector uses one animated liquid fill', (
    tester,
  ) async {
    await _pumpDuration(tester);
    await tester.tap(find.text('>7 дней'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    expect(find.byKey(const ValueKey('duration-liquid-fill')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(_durationSurfaceKey),
      matchesGoldenFile('../golden/goldens/duration_liquid_mid.png'),
    );
  }, skip: _skipPixelGoldens);
}

Future<void> _pumpNav(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 180));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _navSurfaceKey,
        child: ColoredBox(
          color: Color(0xFFF7F7F7),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppFloatingNavBar(currentIndex: 0, onTap: _noopIndex),
            ),
          ),
        ),
      ),
    ),
  );
  final context = tester.element(find.byKey(_navSurfaceKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in AppIconography.bundledAssets)
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pumpAndSettle();
}

Future<void> _pumpMode(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(debugShowCheckedModeBanner: false, home: _ModeHarness()),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCenterCompactNav(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: Color(0xFFF7F7F7),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppFloatingNavBar(
              currentIndex: 2,
              compactDestinationIndex: 2,
              centerCompactMode: true,
              detailMode: true,
              onTap: _noopIndex,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDuration(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 120));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _DurationHarness(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadRubik() async {
  final loader = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await loader.load();
}

void _noopIndex(int _) {}

class _ModeHarness extends StatefulWidget {
  const _ModeHarness();

  @override
  State<_ModeHarness> createState() => _ModeHarnessState();
}

class _ModeHarnessState extends State<_ModeHarness> {
  var _mode = RouteMatchMode.params;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _modeSurfaceKey,
      child: ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RouteModeSwitcher(
              px: _identity,
              mode: _mode,
              onChanged: (value) => setState(() => _mode = value),
            ),
          ),
        ),
      ),
    );
  }
}

double _identity(double value) => value;

class _DurationHarness extends StatefulWidget {
  const _DurationHarness();

  @override
  State<_DurationHarness> createState() => _DurationHarnessState();
}

class _DurationHarnessState extends State<_DurationHarness> {
  var _value = RouteDurationOption.d3_5;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _durationSurfaceKey,
      child: ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DurationSelector(
              px: _identity,
              value: _value,
              onChanged: (value) => setState(() => _value = value),
            ),
          ),
        ),
      ),
    );
  }
}
