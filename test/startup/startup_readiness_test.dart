import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/startup/startup_config.dart';
import 'package:tourism_mobile/core/startup/startup_readiness.dart';

/// A scripted start-up: each dependency can be finished by hand.
class _Fake {
  var hydrated = false;
  var authenticated = false;
  var provisionalAvailable = false;
  var slowHint = false;
  final milestones = <double>[];
  final settled = Completer<void>();
  final catalog = Completer<void>();
  final covers = Completer<void>();
  var provisionalCalls = 0;

  StartupDeps get deps => StartupDeps(
    isHydrated: () => hydrated,
    isAuthenticated: () => authenticated,
    sessionSettled: () => settled.future,
    enterProvisional: () async {
      provisionalCalls++;
      return provisionalAvailable;
    },
    catalogReady: () => catalog.future,
    coversReady: () => covers.future,
  );

  void settleSession({required bool authenticated}) {
    hydrated = true;
    this.authenticated = authenticated;
    settled.complete();
  }

  Future<StartupResult> run(StartupTiming timing) => runStartup(
    deps: deps,
    timing: timing,
    onMilestone: milestones.add,
    onSlowHint: (visible) => slowHint = visible,
  );
}

Future<void> _pump(WidgetTester tester, Duration d) async {
  await tester.pump(d);
  await tester.pump();
}

/// The ceiling timers outlive a test that finishes early; let them run out.
void _t(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await _pump(tester, const Duration(seconds: 12));
  });
}

void main() {
  const timing = StartupTiming();

  _t('a guest is ready as soon as the session is known', (tester) async {
    final fake = _Fake()..hydrated = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await tester.pump();

    expect(result?.authenticated, isFalse);
    expect(fake.milestones.last, 1);
    expect(fake.provisionalCalls, 0);
  });

  _t('an authenticated start waits for the catalog and the covers', (
    tester,
  ) async {
    final fake = _Fake()
      ..hydrated = true
      ..authenticated = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await tester.pump();
    expect(result, isNull);

    fake.catalog.complete();
    await tester.pump();
    expect(result, isNull);

    fake.covers.complete();
    await tester.pump();
    expect(result?.authenticated, isTrue);
    expect(result?.provisional, isFalse);
  });

  _t('a slow catalog is not waited for past the ceiling', (tester) async {
    final fake = _Fake()
      ..hydrated = true
      ..authenticated = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await _pump(tester, const Duration(milliseconds: 3900));
    expect(result, isNull);

    await _pump(tester, const Duration(milliseconds: 200));
    expect(result?.authenticated, isTrue);
  });

  _t('slow covers only get their own ~1 s once the catalog is in', (
    tester,
  ) async {
    final fake = _Fake()
      ..hydrated = true
      ..authenticated = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await tester.pump();
    fake.catalog.complete();
    await _pump(tester, const Duration(milliseconds: 900));
    expect(result, isNull);

    await _pump(tester, const Duration(milliseconds: 200));
    expect(result?.authenticated, isTrue);
  });

  _t('an unfinished session check opens home from the cache at the '
      'ceiling', (tester) async {
    final fake = _Fake()..provisionalAvailable = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await _pump(tester, const Duration(milliseconds: 3900));
    expect(result, isNull);

    await _pump(tester, const Duration(milliseconds: 200));
    expect(result?.authenticated, isTrue);
    expect(result?.provisional, isTrue);
    expect(fake.slowHint, isFalse);
  });

  _t('without a cache the gate shows the hint and waits up to 10 s', (
    tester,
  ) async {
    final fake = _Fake();
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await _pump(tester, const Duration(milliseconds: 4100));
    expect(fake.slowHint, isTrue);
    expect(result, isNull);

    await _pump(tester, const Duration(seconds: 5));
    expect(result, isNull);

    await _pump(tester, const Duration(seconds: 1));
    expect(result?.authenticated, isFalse);
    expect(fake.slowHint, isFalse);
  });

  _t('without a cache a session that settles late is honoured', (tester) async {
    final fake = _Fake();
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await _pump(tester, const Duration(seconds: 6));
    expect(fake.slowHint, isTrue);

    fake.settleSession(authenticated: true);
    await tester.pump();
    await tester.pump();
    expect(fake.slowHint, isFalse);
    // The ceiling has already passed: no further waiting for the catalog.
    expect(result?.authenticated, isTrue);
    expect(result?.provisional, isFalse);
  });

  _t('a session that settles before the ceiling avoids the '
      'provisional path', (tester) async {
    final fake = _Fake()..provisionalAvailable = true;
    StartupResult? result;
    unawaited(fake.run(timing).then((r) => result = r));
    await _pump(tester, const Duration(seconds: 1));
    fake.settleSession(authenticated: false);
    await tester.pump();
    await tester.pump();

    expect(result?.authenticated, isFalse);
    expect(fake.provisionalCalls, 0);
  });
}
