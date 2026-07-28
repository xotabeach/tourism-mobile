import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
