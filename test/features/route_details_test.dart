import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';

const _testConfig = AppConfig(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Test)',
  useMockData: true,
);

Future<void> _openRouteDetails(WidgetTester tester) async {
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
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            const SessionState(
              onboardingCompleted: true,
              displayName: 'Никита',
            ),
          ),
        ),
      ],
      child: const TourismApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsLabel('Маршруты'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хорошо'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Классика Южного берега').first);
  await tester.pumpAndSettle();
}

bool _isSelected(WidgetTester tester, Pattern semanticsLabel) {
  return tester
          .getSemantics(find.bySemanticsLabel(semanticsLabel))
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;
}

void main() {
  testWidgets('gallery expands past half of the screen on swipe up and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    final header = find.byType(RouteMediaHeader);
    expect(tester.getSize(header).height, RouteMediaHeader.collapsedHeight);

    await tester.fling(header, const Offset(0, -160), 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, greaterThan(852 / 2));

    await tester.tap(header, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, RouteMediaHeader.collapsedHeight);

    handle.dispose();
  });

  testWidgets('map pin selects the matching stop and back again', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openRouteDetails(tester);

    final pinLabel = RegExp('Точка 2, Ливадийский дворец');
    final stopLabel = RegExp('Показать остановку 2 на карте');

    await tester.ensureVisible(find.bySemanticsLabel(pinLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isFalse);

    await tester.tap(find.bySemanticsLabel(pinLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isTrue);
    expect(_isSelected(tester, stopLabel), isTrue);

    await tester.tap(find.bySemanticsLabel(stopLabel));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, pinLabel), isTrue);

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

    expect(find.text('Ливадийский дворец'), findsWidgets);
    expect(find.textContaining('Ялтинской конференции'), findsOneWidget);
  });
}
