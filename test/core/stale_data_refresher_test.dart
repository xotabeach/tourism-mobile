import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/cache/stale_data_refresher.dart';

import '../support/test_overrides.dart';

/// Inside a session the caches expire on their own (5–10 minutes). In the
/// background nothing expires for real, so coming back after a long absence
/// showed exactly what was left behind until the user pulled to refresh.
void main() {
  // Свой кеш в общем реестре: сброс наблюдаем прямо на нём, а не через
  // внутренности приложения.
  late ApiCache<String, String> probe;

  Future<void> pump(WidgetTester tester, {required Duration staleAfter}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: StaleDataRefresher(
          staleAfter: staleAfter,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    probe = ApiCache<String, String>(ttl: const Duration(hours: 1));
    probe.set('key', 'значение');
    container.read(apiCacheRegistryProvider).register(probe);
  }

  testWidgets('a long absence clears the caches on return', (tester) async {
    await pump(tester, staleAfter: Duration.zero);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(probe.get('key'), isNull, reason: 'кеш должен быть сброшен');
  });

  testWidgets('a short switch away changes nothing', (tester) async {
    await pump(tester, staleAfter: const Duration(minutes: 15));

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(probe.get('key'), 'значение', reason: 'кеш трогать не за что');
  });

  testWidgets('inactive alone is not a background trip', (tester) async {
    // A notification shade or an incoming call does not stale the data.
    await pump(tester, staleAfter: Duration.zero);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(probe.get('key'), 'значение', reason: 'это не уход в фон');
  });
}
