import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';
import 'package:tourism_mobile/core/design/components/native_liquid_glass.dart';

void main() {
  setUp(() {
    forceFlutterLiquidGlassFallback = true;
  });

  tearDown(() {
    forceFlutterLiquidGlassFallback = false;
  });

  testWidgets('adaptive glass controls build on Flutter fallback path', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Column(
            children: [
              AppAdaptivePrimaryButton(label: 'Продолжить', onPressed: () {}),
              AppGlassIconButton(
                semanticLabel: 'Назад',
                icon: Icons.arrow_back_rounded,
                onPressed: () {},
              ),
              AppSearchFilterRow(
                onFilterTap: () {},
                onSearchChanged: (_) {},
                controller: TextEditingController(),
              ),
              AppFilterChipBar(
                labels: const ['Все', 'Пешком', 'Авто'],
                selected: 'Все',
                onSelected: (_) {},
              ),
              AppFlatIconButton(
                iconAsset: AppIconography.filter,
                semanticLabel: 'Фильтры',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
    expect(
      shouldUseNativeLiquidGlass(tester.element(find.text('Продолжить'))),
      isFalse,
    );
  });

  testWidgets('Android primary button stays Material filled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: AppAdaptivePrimaryButton(label: 'Далее', onPressed: () {}),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('Android glass with white glyph uses solid nav chrome fill', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppGlassSurface(
              fillColor: Color(0x4DFFFFFF),
              contentColor: Colors.white,
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );

      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final fills = decorated
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>()
          .toList();
      expect(
        fills.any(
          (c) =>
              c.r == AppColors.activeNavigationFill.r &&
              c.g == AppColors.activeNavigationFill.g &&
              c.b == AppColors.activeNavigationFill.b,
        ),
        isTrue,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android glass with dark glyph keeps light fill', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      const lightFill = Color(0xC7F4F4F6);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppGlassSurface(
              fillColor: lightFill,
              contentColor: AppColors.primaryInk,
              child: SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );

      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final fills = decorated
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>()
          .toList();
      expect(fills.any((c) => c == lightFill), isTrue);
      expect(
        fills.any(
          (c) =>
              c.r == AppColors.activeNavigationFill.r &&
              c.g == AppColors.activeNavigationFill.g &&
              c.b == AppColors.activeNavigationFill.b &&
              c.a == 1,
        ),
        isFalse,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
