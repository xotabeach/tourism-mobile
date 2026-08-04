import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

void main() {
  test('routeMatchLooksLikeSelfHarm detects crisis phrases', () {
    expect(
      routeMatchLooksLikeSelfHarm('я разбежавшись прыгну со скалы на закате'),
      isTrue,
    );
    expect(routeMatchLooksLikeSelfHarm('хочу умереть'), isTrue);
    expect(routeMatchLooksLikeSelfHarm('хочу пляж и закат'), isFalse);
  });

  testWidgets('RouteMatchScreen params build without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(333, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(333, 1024),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },
          home: const RouteMatchScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('КРЫМТРИП'), findsOneWidget);
    expect(find.text('ПОСТРОЙ МАРШРУТ'), findsOneWidget);
    expect(find.text('По параметрам'), findsOneWidget);
    expect(find.text('Подобрать маршрут'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Собрать маршрут с ИИ'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('RouteMatchScreen AI mode builds without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(393, 852),
                padding: const EdgeInsets.only(top: 59, bottom: 34),
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },
          home: const RouteMatchScreen(
            initialMode: RouteMatchMode.ai,
            pixelReference: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Тревел Агент'), findsWidgets);
    expect(find.text('Сообщение'), findsOneWidget);
  });

  testWidgets('mode morph survives moving the switcher between scroll views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RouteMatchScreen())),
    );
    await tester.pump();

    final params = find.byKey(const ValueKey('route-mode-params'));
    final ai = find.byKey(const ValueKey('route-mode-ai'));
    final initialParams = tester.getSize(params).width;
    final initialAi = tester.getSize(ai).width;

    await tester.tap(find.bySemanticsLabel('Режим подбор с ИИ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getSize(ai).width, greaterThan(initialAi + 1));
    expect(tester.getSize(params).width, lessThan(initialParams - 1));
    await tester.pumpAndSettle();

    final selectedAi = tester.getSize(ai).width;
    await tester.tap(find.bySemanticsLabel('Режим по параметрам'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getSize(ai).width, lessThan(selectedAi - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI chat renders hostile text as data without crash', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RouteMatchScreen(initialMode: RouteMatchMode.ai),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).last,
      '<script>alert(1)</script>',
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Отправить сообщение'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(find.text('<script>alert(1)</script>'), findsOneWidget);
  });

  testWidgets('AI crisis path shows support reply', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RouteMatchScreen(initialMode: RouteMatchMode.ai),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).last,
      'хочу прыгнуть со скалы на закате',
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Отправить сообщение'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('экстренной службой'), findsOneWidget);
    expect(find.text('пиздец'), findsNothing);
  });
}
