import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_collapsing_header.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

import '../support/test_overrides.dart';

double _headerPaintExtent(WidgetTester tester) {
  final render = tester.renderObject<RenderSliverPersistentHeader>(
    find.byType(SliverPersistentHeader),
  );
  return render.geometry!.paintExtent;
}

Future<Element> _openRouteDetails(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: testSessionOverrides(onboardingCompleted: true),
      child: const TourismApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsLabel('Маршруты'));
  await tester.pumpAndSettle();
  final coachButton = tester.widget<InkWell>(
    find
        .ancestor(of: find.text('Хорошо'), matching: find.byType(InkWell))
        .first,
  );
  coachButton.onTap!();
  await tester.pumpAndSettle();
  final shellNavElement = tester.element(find.byType(AppFloatingNavBar));
  await tester.tap(find.text('Классика Южного берега').first);
  await tester.pumpAndSettle();
  return shellNavElement;
}

bool _isSelected(WidgetTester tester, Pattern semanticsLabel) {
  return tester
          .getSemantics(find.bySemanticsLabel(semanticsLabel))
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;
}

void main() {
  testWidgets('owner can preview a route pending moderation', (tester) async {
    const summary = RouteSummary(
      id: 'pending-route',
      name: 'Маршрут на проверке',
      slug: 'pending-route',
      shortDescription: 'Описание',
      stopsCount: 0,
      ownerUserId: 'mock-user',
      visibility: 'private',
      publicationStatus: 'pending_review',
    );
    const detail = RouteDetail(
      id: 'pending-route',
      name: 'Маршрут на проверке',
      slug: 'pending-route',
      shortDescription: 'Описание',
      description: 'Полное описание маршрута',
      stopsCount: 0,
      ownerUserId: 'mock-user',
      visibility: 'private',
      publicationStatus: 'pending_review',
      stops: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          ownRouteDetailProvider.overrideWith((ref, id) async => detail),
        ],
        child: const MaterialApp(
          home: RouteDetailsScreen(
            routeId: 'pending-route',
            initialRoute: summary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-owner-status')), findsOneWidget);
    expect(find.text('На модерации'), findsOneWidget);
    expect(find.bySemanticsLabel('Добавить в избранное'), findsNothing);
  });

  testWidgets('route hero starts expanded and shrinks on scroll', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    expect(find.byType(RouteCollapsingHeader), findsOneWidget);
    expect(
      _headerPaintExtent(tester),
      closeTo(RouteCollapsingHeader.expandedHeight, 0.5),
    );

    await tester.drag(
      find.byKey(const ValueKey('route-details-list')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    final collapsed = _headerPaintExtent(tester);
    expect(collapsed, lessThan(RouteCollapsingHeader.expandedHeight - 40));
    expect(collapsed, lessThanOrEqualTo(120));

    handle.dispose();
  });

  testWidgets('tapping route cover expands the gallery', (tester) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    expect(
      _headerPaintExtent(tester),
      closeTo(RouteCollapsingHeader.expandedHeight, 0.5),
    );

    await tester.tap(
      find.bySemanticsLabel(
        'Обложка маршрута, нажмите, чтобы раскрыть галерею',
      ),
    );
    await tester.pumpAndSettle();

    const galleryMax = 852 * RouteCollapsingHeader.galleryHeightFactor;
    expect(_headerPaintExtent(tester), closeTo(galleryMax, 1.5));
    expect(find.bySemanticsLabel('Галерея маршрута раскрыта'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('route cover photos can be swiped horizontally', (tester) async {
    await _openRouteDetails(tester);

    final pageView = find.descendant(
      of: find.byType(RouteCollapsingHeader),
      matching: find.byType(PageView),
    );
    expect(pageView, findsOneWidget);

    final controller = tester.widget<PageView>(pageView).controller;
    expect(controller, isNotNull);
    expect(controller!.page ?? 0, closeTo(0, 0.05));

    await tester.drag(pageView, const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(controller.page ?? 0, greaterThan(0.5));
  });

  testWidgets('scrolling keeps the hero collapsed until scrolled back', (
    tester,
  ) async {
    await _openRouteDetails(tester);

    expect(
      _headerPaintExtent(tester),
      closeTo(RouteCollapsingHeader.expandedHeight, 0.5),
    );

    await tester.drag(
      find.byKey(const ValueKey('route-details-list')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    final afterScroll = _headerPaintExtent(tester);
    expect(afterScroll, lessThan(RouteCollapsingHeader.expandedHeight - 40));

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('route-details-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );

    await tester.drag(
      find.byKey(const ValueKey('route-details-list')),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();
    expect(
      _headerPaintExtent(tester),
      closeTo(RouteCollapsingHeader.expandedHeight, 0.5),
    );
  });

  testWidgets('map and stop selection does not reposition the page', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    final pinLabel = RegExp('Точка 2, Ливадийский дворец');
    final stopLabel = RegExp('Показать остановку 2 на карте');

    await tester.ensureVisible(find.bySemanticsLabel(pinLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isFalse);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('route-details-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    var position = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.bySemanticsLabel(pinLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isTrue);
    expect(_isSelected(tester, stopLabel), isTrue);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(position, 0.01),
    );

    await tester.ensureVisible(find.bySemanticsLabel(stopLabel));
    await tester.pumpAndSettle();
    position = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.bySemanticsLabel(stopLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isTrue);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(position, 0.01),
    );

    handle.dispose();
  });

  testWidgets('similar routes use the full viewport width', (tester) async {
    await _openRouteDetails(tester);

    final section = find.byKey(const ValueKey('similar-routes-full-bleed'));
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();

    expect(tester.getSize(section).width, 393);
    final list = find.byKey(const ValueKey('similar-routes-list'));
    expect(list, findsOneWidget);
    expect(
      find.descendant(of: list, matching: find.byType(Hero)),
      findsWidgets,
    );
  });

  testWidgets('details navigation expands from the active home item', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final shellNavBefore = await _openRouteDetails(tester);
    final shellNavAfter = tester.element(find.byType(AppFloatingNavBar));
    expect(identical(shellNavBefore, shellNavAfter), isTrue);
    expect(
      tester
          .widget<AppFloatingNavBar>(find.byType(AppFloatingNavBar))
          .detailMode,
      isTrue,
    );

    expect(
      find.bySemanticsLabel('Развернуть навигацию, выбран раздел Главная'),
      findsOneWidget,
    );
    final compactButton = tester.getRect(find.byType(RouteStartButton));
    final compactBar = tester.getRect(
      find.byKey(const ValueKey('app-shell-bottom-bar')),
    );
    expect(compactButton.left, greaterThan(compactBar.left + 58));
    expect(compactButton.top, closeTo(compactBar.bottom - 58, 0.01));

    await tester.tap(find.byKey(const ValueKey('expand-detail-navigation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final movingButton = tester.getRect(find.byType(RouteStartButton));
    expect(movingButton.top, lessThan(compactButton.top));
    expect(movingButton.top, greaterThanOrEqualTo(compactBar.top));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Главная'), findsOneWidget);
    expect(find.byType(RouteCollapsingHeader), findsOneWidget);
    final expandedButton = tester.getRect(find.byType(RouteStartButton));
    expect(expandedButton.bottom, lessThanOrEqualTo(compactBar.bottom - 68));

    await tester.tap(find.bySemanticsLabel('Маршруты'));
    await tester.pump();
    expect(find.byType(RouteStartButton), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(RouteSwipeDeck), findsOneWidget);
    expect(find.text('Хорошо'), findsNothing);

    handle.dispose();
  });

  testWidgets('stop arrow opens the place details screen', (tester) async {
    await _openRouteDetails(tester);

    final arrow = find.ancestor(
      of: find.byTooltip('Открыть место'),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(arrow.at(1));
    await tester.pumpAndSettle();
    await tester.tap(arrow.at(1));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailsScreen), findsOneWidget);
    expect(find.text('Ливадийский дворец'), findsWidgets);
    expect(find.textContaining('Ялтинской конференции'), findsOneWidget);
    expect(
      GoRouter.of(
        tester.element(find.byType(PlaceDetailsScreen)),
      ).state.uri.path,
      contains('/place/'),
    );

    await tester.tap(find.byKey(const ValueKey('place-details-back')));
    await tester.pumpAndSettle();

    final path = GoRouter.of(
      tester.element(find.byType(AppFloatingNavBar)),
    ).state.uri.path;
    // Back must return to the route details we came from, not the places catalog.
    expect(find.byType(PlaceDetailsScreen), findsNothing);
    expect(find.text('Места Крыма'), findsNothing);
    expect(path, startsWith('/routes/'));
    expect(path.contains('/place/'), isFalse, reason: 'path=$path');
    expect(
      find.byKey(const ValueKey('route-details-title')),
      findsOneWidget,
      reason: 'path=$path',
    );
    expect(
      tester
          .widget<AppFloatingNavBar>(find.byType(AppFloatingNavBar))
          .currentIndex,
      1,
    );
    expect(
      tester
          .widget<AppFloatingNavBar>(find.byType(AppFloatingNavBar))
          .detailMode,
      isTrue,
    );
  });
}
