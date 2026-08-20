import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/my_routes/presentation/my_routes_screen.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_screen.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_notifications_inbox_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import 'support/test_overrides.dart';

List<Override> _testOverrides({
  bool onboardingCompleted = false,
  List<Override> additional = const [],
}) {
  return [
    ...testSessionOverrides(onboardingCompleted: onboardingCompleted),
    ...additional,
  ];
}

ProviderScope appWithCompletedOnboarding({
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: _testOverrides(onboardingCompleted: true, additional: overrides),
    child: const TourismApp(),
  );
}

Future<void> openPlacesCatalog(WidgetTester tester) async {
  final context = tester.element(find.byType(HomeScreen));
  unawaited(GoRouter.of(context).pushNamed(AppRouteNames.places));
  await tester.pumpAndSettle();
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

    expect(find.textContaining('ПО НОМЕРУ'), findsOneWidget);
    expect(find.text('Введите ваше имя'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '9991234567');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      '+7 999 123-45-67',
    );
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ЗНАКОМИТЬСЯ'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Никита');
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

  testWidgets('existing account signs in with phone and no repeated consents', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _testOverrides(), child: const TourismApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать путешествие'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9990000000');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      '+7 999 000-00-00',
    );
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('ПОДТВЕРДИТЕ'), findsOneWidget);
    expect(find.textContaining('политикой конфиденциальности'), findsNothing);
    expect(find.textContaining('персональных данных'), findsNothing);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
  });

  testWidgets('shows home and opens places catalog from mock data', (
    WidgetTester tester,
  ) async {
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

    expect(find.textContaining('Привет, Никита'), findsOneWidget);
    await openPlacesCatalog(tester);

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

  testWidgets('home bell opens the notifications inbox', (tester) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Уведомления')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNotificationsInboxScreen), findsOneWidget);
    expect(find.text('Мои уведомления:'), findsOneWidget);
  });

  testWidgets('center screens support leading-edge back swipe', (tester) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подобрать'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteMatchScreen), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('edge-back-hit-area')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RouteMatchScreen), findsNothing);
    expect(find.textContaining('Привет, Никита'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePublishScreen), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('edge-back-hit-area')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RoutePublishScreen), findsNothing);
    expect(find.textContaining('Привет, Никита'), findsOneWidget);
  });

  testWidgets('leaving publish does not restore it from another nav tab', (
    tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Создать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePublishScreen), findsOneWidget);

    await tester.tap(
      find.bySemanticsLabel('Развернуть навигацию, выбран раздел Создать'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Главная'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePublishScreen), findsNothing);

    await tester.tap(find.bySemanticsLabel('Избранное'));
    await tester.pumpAndSettle();
    expect(find.byType(MyRoutesScreen), findsOneWidget);
    expect(find.byType(RoutePublishScreen), findsNothing);
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

  testWidgets('home search replaces body in place', (tester) async {
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

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.text('Люди:'), findsOneWidget);
    expect(find.text('Маршруты:'), findsOneWidget);
  });

  testWidgets('in-place search shows route and profile results', (
    tester,
  ) async {
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
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Никита');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Никита Можаров'), findsOneWidget);
    expect(find.byType(DiscoveryProfileCard), findsOneWidget);
    expect(find.byType(RouteHeroCard), findsWidgets);
  });

  testWidgets('in-place search clears query', (tester) async {
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
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Никита');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '',
    );
  });

  testWidgets('my routes subscriptions use discovery profile cards', (
    tester,
  ) async {
    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Избранное'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подписки'));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveryProfileCard), findsNWidgets(3));
    expect(find.text('Никита Можаров'), findsOneWidget);
    expect(find.text('Продвинутый пешеход'), findsOneWidget);

    final profileSwipe = find.byKey(
      const ValueKey('favorite-dismiss-profile-mock-user'),
    );
    await tester.drag(profileSwipe, const Offset(-72, 0));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryProfileCard), findsNWidgets(3));

    await tester.tap(
      find.byKey(const ValueKey('favorite-remove-action')).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryProfileCard), findsNWidgets(2));
  });

  testWidgets('home shows seven featured routes and expands in place', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 5000);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
    final routes = List.generate(
      9,
      (index) => RouteSummary(
        id: 'featured-$index',
        name: 'Популярный маршрут $index',
        slug: 'featured-$index',
        shortDescription: 'Море и горы',
        stopsCount: 2,
        publicationStatus: 'published',
        visibility: 'public',
      ),
    );

    await tester.pumpWidget(
      appWithCompletedOnboarding(
        overrides: [
          homeRoutesProvider.overrideWith(
            (ref) async => RouteListPage(
              items: routes,
              total: routes.length,
              limit: 100,
              offset: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RouteHeroCard), findsNWidgets(7));
    expect(find.text('Популярный маршрут 7'), findsNothing);

    await tester.tap(find.text('Листать все'));
    await tester.pumpAndSettle();

    expect(find.byType(RouteHeroCard), findsNWidgets(9));
    expect(find.text('Популярный маршрут 8'), findsOneWidget);
    expect(find.text('Свернуть'), findsOneWidget);
  });

  testWidgets('places search queries matching places and clears', (
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 1600);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final placeTitle = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Ай-Петри',
    );

    await tester.pumpWidget(appWithCompletedOnboarding());
    await tester.pumpAndSettle();
    await openPlacesCatalog(tester);

    expect(find.text('Ласточкино гнездо'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ай-Петри');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(placeTitle, findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Ласточкино гнездо'), findsWidgets);
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

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Никита');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(RouteSwipeDeck), findsNothing);
    expect(find.byType(RouteHeroCard), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
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
