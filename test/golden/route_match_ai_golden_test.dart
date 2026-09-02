import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/domain/crimea_cities.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_catalog_match_carousel.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_interactive_controls.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_route_proposal_card.dart';

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

  testWidgets('golden route proposal card — catalog', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: ChatRouteProposalCard(
          card: const RouteProposalCardData(
            proposalId: 'p1',
            title: 'Гора Чок-Сары-Кая',
            stopsCount: 4,
            durationMinutes: 280,
            coverUrl: AppImages.coastPineTwilight,
            rating: 4.9,
            distanceKm: 8.6,
            localityLabel: 'Бахчисарай',
            tags: ['Горы', 'С детьми', 'Пешком', 'Круглый год'],
            budgetLabel: '2 500 ₽',
            difficultyLabel: '3/5',
            cardVariant: RouteProposalCardVariant.catalog,
          ),
          onCreate: () {},
          onSaveDraft: () {},
          onRefine: () {},
          onRebuild: () {},
        ),
      ),
      size: const Size(393, 900),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_proposal_catalog.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden route proposal card — assembled', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: ChatRouteProposalCard(
          card: const RouteProposalCardData(
            proposalId: 'p2',
            title: 'Собранный маршрут',
            stopsCount: 4,
            durationMinutes: 280,
            galleryUrls: [
              AppImages.coastalBayHills,
              AppImages.coastalBayHills,
              AppImages.coastalBayHills,
              AppImages.coastalBayHills,
            ],
            rating: 4.9,
            distanceKm: 8.6,
            localityLabel: 'Бахчисарай',
            tags: ['Горы', 'С детьми', 'Пешком', 'Круглый год'],
            budgetLabel: '2 500 ₽',
            difficultyLabel: '3/5',
            cardVariant: RouteProposalCardVariant.assembled,
            startLabel: 'Площадь Ленина',
            startSubtitle: 'г. Симферополь',
            finishLabel: 'Площадь Ленина',
            finishSubtitle: 'г. Симферополь',
            locations: [
              ProposalLocationItem(
                id: '1',
                title: 'Подножье горы',
                subtitle: '1,7 км',
                index: 1,
              ),
              ProposalLocationItem(
                id: '2',
                title: 'Смотровая площадка',
                subtitle: '1,7 км',
                index: 2,
              ),
              ProposalLocationItem(
                id: '3',
                title: 'Родник',
                subtitle: '1,7 км',
                index: 3,
              ),
              ProposalLocationItem(
                id: '4',
                title: 'Вершина',
                subtitle: '1,7 км',
                index: 4,
              ),
            ],
          ),
          onCreate: () {},
          onSaveDraft: () {},
          onRefine: () {},
          onViewMap: () {},
          onRebuild: () {},
        ),
      ),
      size: const Size(393, 1340),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_proposal_assembled.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden catalog match carousel', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 265,
          child: ChatCatalogMatchCarousel(
            routes: const [
              CatalogRouteItem(
                routeId: 'r1',
                title: 'Гора Чок-Сары-Кая',
                coverUrl: AppImages.coastPineTwilight,
                rating: 4.9,
                distanceKm: 8.6,
                localityLabel: 'Бахчисарай',
                tags: ['Горы', 'С детьми', 'Пешком', 'Круглый год'],
                budgetLabel: '2 500 ₽',
                difficultyLabel: '3/5',
                stopsCount: 4,
                durationMinutes: 280,
              ),
              CatalogRouteItem(routeId: 'r2', title: 'Второй маршрут'),
              CatalogRouteItem(routeId: 'r3', title: 'Третий маршрут'),
            ],
            onOpenRoute: (_) {},
          ),
        ),
      ),
      size: const Size(393, 700),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/chat_catalog_carousel.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden city select — collapsed and open', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 241,
              child: ChatSelectControl(
                px: (v) => v,
                data: _citySelect,
                onSelected: (_) {},
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 241,
              child: ChatSelectControl(
                key: const ValueKey('open-select'),
                px: (v) => v,
                data: _citySelect,
                onSelected: (_) {},
              ),
            ),
          ],
        ),
      ),
      size: const Size(393, 560),
      afterPump: (tester) async {
        await tester.tap(
          find
              .descendant(
                of: find.byKey(const ValueKey('open-select')),
                matching: find.byKey(const ValueKey('chat-select-header')),
              )
              .first,
        );
        await tester.pumpAndSettle();
      },
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/chat_city_select.png'),
      skip: _skipPixelGoldens,
    );
  });
}

final _citySelect = RouteChatSelectData(
  id: 'city',
  label: 'Стартовый город',
  placeholder: 'Город',
  options: [
    for (final city in crimeaCities) SelectOptionItem(value: city, label: city),
  ],
);

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = _phoneSize,
  Future<void> Function(WidgetTester tester)? afterPump,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
  if (afterPump != null) {
    await afterPump(tester);
  }
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
