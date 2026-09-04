import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/settings/application/motion_preference.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_prefs_screens.dart';

import '../../support/test_overrides.dart';

/// «Меньше анимаций»: один флаг гасит длительности во всём приложении —
/// иначе настройку пришлось бы протаскивать в сотню виджетов.
void main() {
  setUp(() => AppMotion.reduceMotion = false);
  tearDown(() => AppMotion.reduceMotion = false);

  test('the flag zeroes every duration and leaves curves alone', () {
    expect(AppMotion.normal, const Duration(milliseconds: 180));

    AppMotion.reduceMotion = true;

    expect(AppMotion.fast, Duration.zero);
    expect(AppMotion.normal, Duration.zero);
    expect(AppMotion.modeMorph, Duration.zero);
    expect(AppMotion.navTint, Duration.zero);
    // Кривые остаются: при нулевой длительности они ни на что не влияют,
    // а код, который их читает, не должен ветвиться.
    expect(AppMotion.standard, isNotNull);
  });

  testWidgets('the settings toggle turns it on', (tester) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SettingsPerformanceScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(reduceMotionProvider), isFalse);
    // Тумблер в настройках — свой виджет, не Material Switch.
    await tester.tap(find.text('Меньше анимаций'));
    await tester.pump();

    expect(container.read(reduceMotionProvider), isTrue);
    expect(AppMotion.normal, Duration.zero);
  });
}
