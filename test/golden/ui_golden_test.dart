import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

const _goldenKey = ValueKey('golden-surface');
const _phoneSize = Size(393, 852);
const _testConfig = AppConfig(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип Golden',
  useMockData: true,
);

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
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_list_card.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('golden route slider resting', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame());
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/slider_resting.png'),
    );
  }, skip: _skipPixelGoldens);

  testWidgets('swipe onboarding overlays the first deck card', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(showCoach: true));
    expect(find.byType(RouteSwipeCoachCard), findsOneWidget);
    // The deck keeps its three cards; the coach only dims the front one.
    expect(find.byType(RouteHeroCard), findsNWidgets(3));

    final coach = tester.getRect(find.byType(RouteSwipeCoachCard));
    final frontCard = tester.getRect(find.byType(RouteHeroCard).last);
    expect(coach, frontCard);
  });

  testWidgets('golden swipe onboarding', (tester) async {
    await _pumpGolden(tester, const _RoutesGoldenFrame(showCoach: true));
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/swipe_onboarding.png'),
    );
  }, skip: _skipPixelGoldens);

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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        if (completedOnboarding)
          sessionProvider.overrideWith(
            (ref) => SessionController(
              const SessionState(
                onboardingCompleted: true,
                displayName: 'Никита',
              ),
            ),
          ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
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

void _noop() {}

void _noopString(String _) {}

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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppFloatingNavBar(
            currentIndex: _index,
            onTap: (index) => setState(() => _index = index),
          ),
        ),
      ),
    );
  }
}
