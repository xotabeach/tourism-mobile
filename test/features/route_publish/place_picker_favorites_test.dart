import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/favorites/application/favorites_provider.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_place_picker_sheet.dart';

import '../../support/test_overrides.dart';

/// Маршрут обычно собирают из уже отмеченных мест — до этого их приходилось
/// вспоминать по названию и искать заново.
void main() {
  testWidgets('the place picker can list favorites only', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 900);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);

    // Мок отдаёт данные через Future.delayed: без runAsync таймер не
    // тикает, и await на провайдере висит до конца теста.
    late final String favoriteName;
    late final String otherName;
    await tester.runAsync(() async {
      final places = await container.read(placesListProvider.future);
      final favorite = places.items.first;
      favoriteName = favorite.name;
      otherName = places.items
          .firstWhere((item) => item.id != favorite.id)
          .name;
      await container.read(favoritesProvider.notifier).addPlace(favorite.id);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRoutePlacePicker(
                    context,
                    title: 'Куда идём?',
                  ),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    // Не pumpAndSettle: скелетон списка мерцает бесконечной анимацией и
    // «устояться» ему не суждено.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(favoriteName), findsWidgets);
    expect(find.text(otherName), findsWidgets);

    await tester.tap(find.text('Из избранного'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(favoriteName), findsOneWidget);
    expect(find.text(otherName), findsNothing);
  });
}
