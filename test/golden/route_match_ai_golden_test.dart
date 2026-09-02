import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';
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
        ),
      ),
      size: const Size(393, 820),
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
        ),
      ),
      size: const Size(393, 1280),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/route_proposal_assembled.png'),
      skip: _skipPixelGoldens,
    );
  });
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = _phoneSize,
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
