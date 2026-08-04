import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';

import 'support/test_overrides.dart';

List<Override> _testOverrides({bool onboardingCompleted = false}) {
  return testSessionOverrides(onboardingCompleted: onboardingCompleted);
}

ProviderScope appWithCompletedOnboarding() {
  return ProviderScope(
    overrides: _testOverrides(onboardingCompleted: true),
    child: const TourismApp(),
  );
}

void main() {
  testWidgets('welcome leads into mock auth and home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _testOverrides(), child: const TourismApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ИДЕАЛЬНЫЙ'), findsOneWidget);
    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ПУТНИК'), findsOneWidget);
    final identityFields = find.byType(TextFormField);
    await tester.enterText(identityFields.at(0), 'Никита');
    await tester.enterText(identityFields.at(1), '9991234567');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(identityFields.at(1)).controller?.text,
      '+7 999 123-45-67',
    );
    await tester.tap(find.text('Продолжить'));
    // The OTP screen shows a perpetually blinking caret, so settle the route
    // transition with bounded pumps instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.textContaining('политикой конфиденциальности'));
    await tester.tap(find.textContaining('персональных данных'));
    await tester.pump();
    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    expect(find.textContaining('ПОСТРОЙ'), findsOneWidget);
  });

  testWidgets('shows home and opens places catalog from mock data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Места Крыма'), findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsOneWidget);
  });

  testWidgets('home greeting opens profile tab', (WidgetTester tester) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Привет, Никита'));
    await tester.pumpAndSettle();

    expect(find.text('Достижения:'), findsOneWidget);
  });

  testWidgets('center screens use brand app bar without bottom scrim', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подобрать'));
    await tester.pumpAndSettle();

    expect(find.byType(RouteMatchScreen), findsOneWidget);
    expect(find.text('КРЫМТРИП'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-shell-bottom-scrim')), findsNothing);
    expect(_scrollBrandBarOpacity(tester), 0);
    expect(find.bySemanticsLabel('Назад'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('route-match-params-scroll')),
      const Offset(0, -55),
    );
    await tester.pump();
    expect(_scrollBrandBarOpacity(tester), inExclusiveRange(0, 1));
    await tester.drag(
      find.byKey(const ValueKey('route-match-params-scroll')),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(_scrollBrandBarOpacity(tester), 1);
    expect(find.bySemanticsLabel('Назад'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutePublishScreen), findsOneWidget);
    expect(find.text('КРЫМТРИП'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-shell-bottom-scrim')), findsNothing);
    expect(_scrollBrandBarOpacity(tester), 0);

    await tester.drag(
      find.byKey(const ValueKey('route-publish-scroll')),
      const Offset(0, -55),
    );
    await tester.pump();
    expect(_scrollBrandBarOpacity(tester), inExclusiveRange(0, 1));
    await tester.drag(
      find.byKey(const ValueKey('route-publish-scroll')),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(_scrollBrandBarOpacity(tester), 1);
    expect(find.bySemanticsLabel('Назад'), findsOneWidget);
  });

  testWidgets('home search filters visible routes and clears', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    expect(find.text('Классика Южного берега'), findsOneWidget);
    expect(find.text('Наследие Бахчисарая'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Бахчисар');
    await tester.pump();

    expect(find.text('Классика Южного берега'), findsNothing);
    expect(find.text('Наследие Бахчисарая'), findsOneWidget);

    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pump();

    expect(find.text('Классика Южного берега'), findsOneWidget);
    expect(find.text('Наследие Бахчисарая'), findsOneWidget);
  });

  testWidgets('places search queries matching places and clears', (
    WidgetTester tester,
  ) async {
    final placeTitle = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Ай-Петри',
    );

    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Ласточкино гнездо'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ай-Петри');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(placeTitle, findsOneWidget);
    expect(find.text('Ласточкино гнездо'), findsNothing);

    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();

    expect(find.text('Ласточкино гнездо'), findsOneWidget);
  });

  testWidgets('routes tab shows swipe deck from mock data', (
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Маршруты'));
    await tester.pumpAndSettle();

    expect(find.text('Хорошо'), findsOneWidget);
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Хорошо'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(RouteSwipeDeck), findsOneWidget);
    expect(find.text('Классика Южного берега'), findsWidgets);

    await tester.tap(find.text('Классика Южного берега').first);
    await tester.pumpAndSettle();

    expect(find.text('КрымТрип редакция'), findsWidgets);
  });
}

double _scrollBrandBarOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(find.byKey(const ValueKey('scroll-brand-bar-opacity')))
      .opacity;
}
