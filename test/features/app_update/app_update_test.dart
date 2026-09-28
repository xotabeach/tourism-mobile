import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/app_update/application/app_update_controller.dart';
import 'package:tourism_mobile/features/app_update/data/version_policy_repository.dart';
import 'package:tourism_mobile/features/app_update/domain/version_policy.dart';
import 'package:tourism_mobile/features/app_update/presentation/app_update_host.dart';

/// BACKEND-5: soft prompt, then a block, for builds older than the APK.
void main() {
  const soft = VersionPolicy(
    kind: UpdateKind.soft,
    latestVersion: '0.3.1',
    downloadUrl: 'https://example.org/download',
  );
  const hard = VersionPolicy(
    kind: UpdateKind.hard,
    latestVersion: '0.3.1',
    downloadUrl: 'https://example.org/download',
  );

  group('policy parsing', () {
    test('an unknown kind or a missing link reads as no update', () {
      expect(
        VersionPolicy.fromJson(const {
          'update_kind': 'explode',
          'download_url': 'https://example.org/d',
        }).kind,
        UpdateKind.none,
      );
      expect(
        VersionPolicy.fromJson(const {'update_kind': 'hard'}).kind,
        UpdateKind.none,
      );
      expect(
        VersionPolicy.fromJson(const {
          'update_kind': 'hard',
          'download_url': 'http://insecure.example/d',
        }).kind,
        UpdateKind.none,
      );
    });

    test('the store link wins once there is one', () {
      final policy = VersionPolicy.fromJson(const {
        'update_kind': 'soft',
        'download_url': 'https://example.org/download',
        'store_url': 'https://store.example/app',
        'hard_at': '2026-10-01T12:00:00Z',
      });
      expect(policy.updateUri.toString(), 'https://store.example/app');
      expect(policy.hardAt, DateTime.utc(2026, 10, 1, 12));
    });
  });

  group('controller', () {
    late _FakeRepository repository;
    late MemoryUpdateSnoozeStore snooze;
    late DateTime now;

    AppUpdateController build({bool supported = true}) => AppUpdateController(
      repository: repository,
      snoozeStore: snooze,
      clock: () => now,
      supported: supported,
    );

    setUp(() {
      repository = _FakeRepository();
      snooze = MemoryUpdateSnoozeStore();
      now = DateTime.utc(2026, 9, 28, 12);
    });

    test('«Позже» hides the prompt for a day, for that version only', () async {
      repository.next = soft;
      final controller = build();
      await controller.onStart();
      expect(controller.state.showSoft, isTrue);

      await controller.later();
      expect(controller.state.showSoft, isFalse);

      now = now.add(const Duration(hours: 7));
      await controller.onResumed();
      expect(controller.state.showSoft, isFalse, reason: 'snoozed 7 h ago');

      now = now.add(const Duration(hours: 18));
      await controller.onResumed();
      expect(controller.state.showSoft, isTrue, reason: 'a day has passed');
    });

    test('a background return rechecks only after six hours', () async {
      repository.next = VersionPolicy.none;
      final controller = build();
      await controller.onStart();
      now = now.add(const Duration(hours: 1));
      await controller.onResumed();
      expect(repository.calls, 1);
      now = now.add(const Duration(hours: 5));
      await controller.onResumed();
      expect(repository.calls, 2);
    });

    test('while blocked every return rechecks, so an unblock lands', () async {
      repository.next = hard;
      final controller = build();
      await controller.onStart();
      expect(controller.state.blocked, isTrue);

      repository.next = VersionPolicy.none;
      now = now.add(const Duration(minutes: 1));
      await controller.onResumed();
      expect(controller.state.blocked, isFalse);
    });

    test('a failed check never blocks', () async {
      repository.error = true;
      final controller = build();
      await controller.onStart();
      expect(controller.state.blocked, isFalse);
      expect(controller.state.showSoft, isFalse);
    });

    test('without an update source (iOS) nothing is asked', () async {
      repository.next = hard;
      final controller = build(supported: false);
      await controller.onStart();
      expect(repository.calls, 0);
      expect(controller.state.blocked, isFalse);
    });
  });

  group('host', () {
    Future<List<Uri>> pumpHost(
      WidgetTester tester,
      VersionPolicy policy,
    ) async {
      final launched = <Uri>[];
      final repository = _FakeRepository()..next = policy;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateControllerProvider.overrideWith(
              (ref) => AppUpdateController(
                repository: repository,
                snoozeStore: MemoryUpdateSnoozeStore(),
                supported: true,
              ),
            ),
            updateLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
          ],
          child: MaterialApp(
            home: Stack(
              children: [
                Scaffold(
                  body: TextButton(
                    onPressed: () => launched.add(Uri.parse('tap:under')),
                    child: const Text('Экран под слоем'),
                  ),
                ),
                const AppUpdateHost(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return launched;
    }

    testWidgets('the soft prompt updates or goes away', (tester) async {
      final launched = await pumpHost(tester, soft);
      expect(find.text('Доступна новая версия'), findsOneWidget);

      await tester.tap(find.text('Обновить'));
      await tester.pump();
      expect(launched, [Uri.parse('https://example.org/download')]);

      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(find.text('Доступна новая версия'), findsNothing);
    });

    testWidgets('the block covers the app and cannot be dismissed', (
      tester,
    ) async {
      final launched = await pumpHost(tester, hard);
      expect(find.text('Нужно обновить приложение'), findsOneWidget);
      expect(find.text('Позже'), findsNothing);

      await tester.tap(find.text('Экран под слоем'), warnIfMissed: false);
      await tester.pump();
      expect(launched, isEmpty, reason: 'nothing underneath takes taps');

      await tester.tap(find.text('Обновить'));
      await tester.pump();
      expect(launched, [Uri.parse('https://example.org/download')]);
    });

    testWidgets('no update shows nothing', (tester) async {
      await pumpHost(tester, VersionPolicy.none);
      expect(find.text('Доступна новая версия'), findsNothing);
      expect(find.text('Нужно обновить приложение'), findsNothing);
    });
  });
}

class _FakeRepository implements VersionPolicyRepository {
  VersionPolicy next = VersionPolicy.none;
  bool error = false;
  int calls = 0;

  @override
  Future<VersionPolicy> fetch() async {
    calls++;
    if (error) {
      throw Exception('offline');
    }
    return next;
  }
}
