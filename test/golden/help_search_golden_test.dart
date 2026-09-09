import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/settings/data/help_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

const _surface = ValueKey('help-screen-golden');
final _skipPixels =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

class _HelpRepository implements HelpRepository {
  static const article = HelpArticle(
    id: 'points-earn',
    revision: 1,
    appVersion: '0.2.31',
    title: 'Когда начисляются баллы',
    excerpt: 'Проверьте статус маршрута и историю начислений в профиле.',
    body: 'Тестовая инструкция для проверки отображения.',
  );

  @override
  Future<HelpArticle> read(HelpArticle article) async => article;

  @override
  Future<HelpSearchResult> search(String query) async =>
      const HelpSearchResult(available: true, articles: [article]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
          'Rubik',
        )..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!File('${sdk.path}/bin/flutter').existsSync()) {
      if (sdk.parent.path == sdk.path) {
        throw StateError('Flutter SDK not found');
      }
      sdk = sdk.parent;
    }
    final icons = File(
      '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(width, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          helpRepositoryProvider.overrideWithValue(_HelpRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: _surface,
            child: Material(child: SettingsSupportScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('help search card matches the surrounding settings cards', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(_surface),
      matchesGoldenFile('goldens/help_search_idle.png'),
    );
    await tester.enterText(find.byType(TextField), 'Не начислились баллы');
    await tester.pump();
    await tester.tap(find.text('Найти инструкцию'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(_surface),
      matchesGoldenFile('goldens/help_search_results.png'),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text('Чат с поддержкой')).dy,
      lessThan(852 - 130),
    );
    await expectLater(
      find.byKey(_surface),
      matchesGoldenFile('goldens/help_search_bottom.png'),
    );
  }, skip: _skipPixels);

  testWidgets('help card remains usable on a narrow screen with large text', (
    tester,
  ) async {
    await pumpScreen(tester, width: 320, scale: 1.5);
    await tester.enterText(find.byType(TextField), 'Не начислились баллы');
    await tester.pump();
    await tester.ensureVisible(find.text('Найти инструкцию'));
    await tester.tap(find.text('Найти инструкцию'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Написать оператору'));
    expect(find.text(_HelpRepository.article.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
