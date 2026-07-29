import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

import '../support/test_overrides.dart';

const _goldenKey = ValueKey('golden-surface');
const _phoneSize = Size(393, 852);

const _routes = [
  RouteSummary(
    id: 'route-south-coast',
    name: 'Классика Южного берега',
    slug: 'south-coast-classics',
    shortDescription: 'Дворцы и символ Крыма за один день у Ялты.',
    stopsCount: 3,
    distanceMeters: 28000,
    difficulty: 'easy',
    transportMode: 'car',
    authorLabel: 'КрымТрип редакция',
    coverImageUrl: AppImages.welcomeSunset,
  ),
  RouteSummary(
    id: 'route-bakhchisaray',
    name: 'Наследие Бахчисарая',
    slug: 'bakhchisaray-heritage',
    shortDescription: 'Ханский дворец и пещерный город Чуфут-Кале.',
    stopsCount: 2,
    distanceMeters: 12000,
    difficulty: 'moderate',
    transportMode: 'car',
    authorLabel: 'Никита',
    coverImageUrl: AppImages.coastPineTwilight,
  ),
  RouteSummary(
    id: 'route-coast-trail',
    name: 'Море и сосны: Фиолент — Новый Свет',
    slug: 'coast-pine-trail',
    shortDescription: 'Скалистый берег, лесные тропы и бухты у моря.',
    stopsCount: 2,
    distanceMeters: 95000,
    difficulty: 'moderate',
    transportMode: 'car',
    authorLabel: 'Никита',
    coverImageUrl: AppImages.capeFiolentFog,
  ),
];

/// Baselines are recorded on macOS. Linux CI renders text and blur a few
/// percent differently, so it runs only the structural expectations below.
/// Set `SKIP_PIXEL_GOLDENS=1` to skip them on macOS too.
final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  forceFlutterLiquidGlassFallback = true;
  setUpAll(_loadGoldenFonts);

  testWidgets('golden welcome', (tester) async {
    await _pumpGolden(tester, const WelcomeScreen());
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/welcome.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden home top', (tester) async {
    await _pumpGolden(
      tester,
      Stack(
        children: [
          const HomeScreen(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 34,
            child: AppFloatingNavBar(currentIndex: 0, onTap: (_) {}),
          ),
        ],
      ),
      completedOnboarding: true,
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/home_top.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden route list card', (tester) async {
    await _pumpGolden(
      tester,
      ColoredBox(
        color: AppColors.pageSurface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: RouteHeroCard(
                route: _routes[1],
                height: 304,
                interactive: false,
                tags: ['Горы', 'С детьми', 'Пешком'],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Сложность:'), findsNothing);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_list_card.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden route slider resting', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame());
    expect(find.text('Сложность:'), findsWidgets);
    expect(find.byType(AppFilteredOpacity), findsWidgets);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/slider_resting.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden route details top chrome', (tester) async {
    await _pumpGolden(tester, const _RouteDetailsGoldenFrame());
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_details_top.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('swipe onboarding is a standalone first deck card', (
    tester,
  ) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(showCoach: true));
    expect(find.byType(RouteSwipeCoachCard), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(RouteSwipeCoachCard),
        matching: find.byType(RouteHeroCard),
      ),
      findsNothing,
    );
    expect(find.byType(RouteHeroCard), findsNWidgets(2));
  });

  testWidgets('golden swipe onboarding', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(showCoach: true));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/swipe_onboarding.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden iOS swipe onboarding glass', (tester) async {
    await _pumpGolden(
      tester,
      const _RoutesGoldenFrame(showCoach: true),
      platform: TargetPlatform.iOS,
    );
    final cta = tester.widget<AppGlassSurface>(
      find.byKey(const ValueKey('route-swipe-coach-cta-glass')),
    );
    expect(cta.blur, 18);
    expect(cta.fillColor.a, closeTo(0.38, 0.01));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/swipe_onboarding_ios.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('Android swipe coach keeps the neutral CTA surface', (
    tester,
  ) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(showCoach: true));
    final cta = tester.widget<AppGlassSurface>(
      find.byKey(const ValueKey('route-swipe-coach-cta-glass')),
    );
    expect(cta.blur, 0);
    expect(cta.fillColor.a, closeTo(0.24, 0.01));
  });

  testWidgets('primary commands use glass only on iOS', (tester) async {
    const button = Center(
      child: SizedBox(
        width: 280,
        child: AppAdaptivePrimaryButton(label: 'Продолжить', onPressed: _noop),
      ),
    );

    await _pumpGolden(tester, button, platform: TargetPlatform.iOS);
    expect(
      find.descendant(
        of: find.byType(AppAdaptivePrimaryButton),
        matching: find.byType(AppGlassSurface),
      ),
      findsOneWidget,
    );

    await _pumpGolden(tester, button);
    expect(
      find.descendant(
        of: find.byType(AppAdaptivePrimaryButton),
        matching: find.byType(AppGlassSurface),
      ),
      findsNothing,
    );
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('golden swipe right progress', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(debugProgress: 0.72));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/swipe_right.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden swipe left progress', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(debugProgress: -0.72));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/swipe_left.png'),
    );
  }, skip: _skipPixelGoldens);

  for (final index in [0, 1, 2]) {
    testWidgets('golden nav selected $index', (tester) async {
      await _pumpGolden(
        tester,
        ColoredBox(
          color: AppColors.pageSurface,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppFloatingNavBar(currentIndex: index, onTap: (_) {}),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/nav_$index.png'),
      );
    }, skip: _skipPixelGoldens);
  }

  testWidgets('nav clears the liquid bridge after tab transition', (
    tester,
  ) async {
    await _pumpGolden(tester, const _NavHarness());
    await tester.tap(find.bySemanticsLabel('Маршруты'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/nav_1.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden nav long jump keeps liquid bridge compact', (
    tester,
  ) async {
    await _pumpGolden(tester, const _NavHarness());
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/nav_0_to_4_mid.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('responsive Android frame has no overflow', (tester) async {
    await _pumpGolden(
      tester,
      const _RoutesGoldenFrame(),
      size: const Size(412, 915),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe travel is restrained and indicator stays compact', (
    tester,
  ) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame());
    final card = find.byKey(const ValueKey('route-swipe-card-translation'));
    final gesture = await tester.startGesture(tester.getCenter(card));

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('swipe-action-indicator'))),
      const Size.square(42),
    );

    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    final transform = tester.widget<Transform>(card);
    expect(transform.transform.getTranslation().x.abs(), lessThanOrEqualTo(45));
    expect(
      tester.getSize(find.byKey(const ValueKey('swipe-action-indicator'))),
      const Size.square(42),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('back cards promote continuously after a committed swipe', (
    tester,
  ) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame());
    final front = find.byKey(const ValueKey('route-swipe-card-translation'));
    final promotedRoute = find.byKey(
      const ValueKey('route-layer-route-bakhchisaray'),
    );
    final restingTop = tester.widget<Positioned>(promotedRoute).top!;
    final gesture = await tester.startGesture(tester.getCenter(front));

    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    final earlyDragTop = tester.widget<Positioned>(promotedRoute).top!;
    expect((earlyDragTop - restingTop).abs(), lessThan(1));

    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    final promotedTop = tester.widget<Positioned>(promotedRoute).top!;
    expect(promotedTop, closeTo(10, 0.01));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    final settleStartTop = tester.widget<Positioned>(promotedRoute).top!;
    expect(settleStartTop, closeTo(promotedTop, 0.01));

    await tester.pump(const Duration(milliseconds: 170));
    final settleMidTop = tester.widget<Positioned>(promotedRoute).top!;
    expect(settleMidTop, greaterThan(settleStartTop));
    expect(settleMidTop, lessThan(17));

    await tester.pumpAndSettle();
    expect(tester.widget<Positioned>(promotedRoute).top, closeTo(17, 0.01));
  });

  testWidgets('small phone and 1.3 text scale have no overflow', (
    tester,
  ) async {
    await _pumpGolden(
      tester,
      const _RoutesGoldenFrame(showCoach: true),
      size: const Size(360, 740),
      textScaler: const TextScaler.linear(1.3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nav keeps 48px targets and reduced motion', (tester) async {
    await _pumpGolden(tester, const _NavHarness(), disableAnimations: true);

    for (final label in [
      'Главная',
      'Маршруты',
      'Подобрать',
      'Карта',
      'Профиль',
    ]) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.bySemanticsLabel('Маршруты'));
    await tester.pump();
    await tester.pump(AppMotion.reduced);
    await tester.pump();
    final semantics = tester.getSemantics(find.bySemanticsLabel('Маршруты'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  bool completedOnboarding = false,
  Size size = _phoneSize,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: completedOnboarding),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light.copyWith(platform: platform),
        builder: (context, appChild) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: textScaler,
              disableAnimations: disableAnimations,
            ),
            child: appChild!,
          );
        },
        home: RepaintBoundary(
          key: _goldenKey,
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    ),
  );
  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in [
        ...AppIconography.bundledAssets,
        AppImages.welcomeSunset,
        AppImages.coastPineTwilight,
        AppImages.capeFiolentFog,
        AppImages.coastalBayHills,
        AppImages.travelerPortrait,
      ])
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pump();
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

class _RoutesGoldenFrame extends StatelessWidget {
  const _RoutesGoldenFrame({this.debugProgress, this.showCoach = false});

  final double? debugProgress;
  final bool showCoach;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageSurface,
      child: Stack(
        children: [
          Column(
            children: [
              const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    0,
                  ),
                  child: Column(
                    children: [
                      AppSearchFilterRow(
                        onSearchTap: _noop,
                        onFilterTap: _noop,
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppFilterChipBar(
                        labels: ['Все', 'Море', 'Горы', 'Еда', 'Лес'],
                        selected: 'Все',
                        onSelected: _noopString,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RouteSwipeDeck(
                  routes: _routes,
                  onSwipe: _noopSwipe,
                  debugProgress: debugProgress,
                  showCoach: showCoach,
                  onCoachDismiss: _noop,
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 34,
            child: AppFloatingNavBar(currentIndex: 1, onTap: (_) {}),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailsGoldenFrame extends StatelessWidget {
  const _RouteDetailsGoldenFrame();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        RouteDetailsScreen(routeId: 'route-south-coast'),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0xF2FFFFFF),
                    AppColors.elevatedSurface,
                  ],
                  stops: [0, 0.46, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 34,
          child: AppFloatingNavBar(
            currentIndex: 1,
            detailMode: true,
            onStartRoute: _noop,
            onTap: _noopIndex,
          ),
        ),
      ],
    );
  }
}

void _noop() {}

void _noopString(String _) {}

void _noopSwipe(RouteSummary _, RouteSwipeAction _) {}

void _noopIndex(int _) {}

class _NavHarness extends StatefulWidget {
  const _NavHarness();

  @override
  State<_NavHarness> createState() => _NavHarnessState();
}

class _NavHarnessState extends State<_NavHarness> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageSurface,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppFloatingNavBar(
              currentIndex: _index,
              onTap: (index) => setState(() => _index = index),
            ),
          ),
        ),
      ),
    );
  }
}
