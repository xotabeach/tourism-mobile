import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/app.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/startup/krymtrip_logo.dart';
import 'package:tourism_mobile/core/startup/startup_config.dart';
import 'package:tourism_mobile/core/startup/startup_gate.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/auth/presentation/auth_identity_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/data/session_identity_cache.dart';
import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

import '../support/test_overrides.dart';

class _RejectingAuth implements AuthRepository {
  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      Future.error(const AuthFailure('revoked'));

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A cold start with the gate switched on. [hydrate] is started the way the
/// real provider does it.
Future<SessionController> _pumpStart(
  WidgetTester tester, {
  required bool signedIn,
  AuthRepository? auth,
  List<Override> extra = const [],
}) async {
  final storage = MemorySecureStorage();
  if (signedIn) {
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'mock-refresh',
    );
  }
  final controller = SessionController(
    authRepository: auth ?? MockAuthRepository(),
    secureStorage: storage,
    identityCache: MemorySessionIdentityCache(),
    useMockData: true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testAppConfig),
        secureStorageProvider.overrideWithValue(storage),
        searchHistoryStoreProvider.overrideWithValue(
          MemorySearchHistoryStore(),
        ),
        startupGateEnabledProvider.overrideWithValue(true),
        sessionProvider.overrideWith((ref) {
          unawaited(controller.hydrate());
          return controller;
        }),
        ...extra,
      ],
      child: const TourismApp(),
    ),
  );
  await tester.pump();
  return controller;
}

Future<void> _elapse(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

class _Probe extends StatefulWidget {
  const _Probe(this.log);

  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init');
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  tearDown(() => AppMotion.reduceMotion = false);

  testWidgets('a guest sees the preloader for the minimum time, then the '
      'welcome screen', (tester) async {
    await _pumpStart(tester, signedIn: false);
    expect(find.byType(KrymtripLogo), findsOneWidget);

    await _elapse(tester, const Duration(milliseconds: 1300));
    expect(find.byType(KrymtripLogo), findsOneWidget);

    await _elapse(tester, const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(KrymtripLogo), findsNothing);
    expect(find.text('Начать путешествие'), findsOneWidget);
  });

  testWidgets('a signed-in start goes straight to home and never shows '
      'Welcome afterwards', (tester) async {
    await _pumpStart(tester, signedIn: true);
    expect(find.byType(KrymtripLogo), findsOneWidget);

    await _elapse(tester, const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.byType(KrymtripLogo), findsNothing);
    expect(find.text('Начать путешествие'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TourismApp)),
    );
    expect(container.read(startupGateOpenProvider), isFalse);
  });

  testWidgets('the screen under the preloader is silent and inert', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpStart(tester, signedIn: false);

    // Screen readers hear the preloader, not the welcome screen beneath it.
    expect(find.bySemanticsLabel('Загрузка'), findsOneWidget);
    expect(find.bySemanticsLabel('Начать путешествие'), findsNothing);

    // Taps do not reach the screen underneath either.
    await tester.tap(
      find.text('Начать путешествие', skipOffstage: false),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(AuthIdentityScreen, skipOffstage: false), findsNothing);

    await _elapse(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Начать путешествие'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('reduce-motion: no waiting, no fade', (tester) async {
    AppMotion.reduceMotion = true;
    await _pumpStart(tester, signedIn: false);

    await _elapse(tester, const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(KrymtripLogo), findsNothing);
    expect(find.text('Начать путешествие'), findsOneWidget);
  });

  testWidgets('a rejected saved login lands on Welcome with a one-time '
      'notice', (tester) async {
    final controller = await _pumpStart(
      tester,
      signedIn: true,
      auth: _RejectingAuth(),
    );

    await _elapse(tester, const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Сессия истекла, войдите снова'), findsOneWidget);
    expect(find.text('Начать путешествие'), findsOneWidget);
    // Picked up by the screen, so a rebuild or a return would not repeat it.
    expect(controller.state.sessionExpiredNotice, isFalse);
  });

  testWidgets('the gate is off in the shared test setup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(),
        child: const TourismApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(KrymtripLogo), findsNothing);
    expect(find.text('Начать путешествие'), findsOneWidget);
  });

  testWidgets('closing the gate does not re-create the app underneath', (
    tester,
  ) async {
    final log = <String>[];
    final controller = SessionController(
      authRepository: MockAuthRepository(),
      secureStorage: MemorySecureStorage(),
      identityCache: MemorySessionIdentityCache(),
      useMockData: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupGateEnabledProvider.overrideWithValue(true),
          sessionProvider.overrideWith((ref) {
            unawaited(controller.hydrate());
            return controller;
          }),
        ],
        child: MaterialApp(home: StartupGate(child: _Probe(log))),
      ),
    );
    await tester.pump();
    expect(find.byType(KrymtripLogo), findsOneWidget);

    await _elapse(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(KrymtripLogo), findsNothing);
    expect(log, ['init'], reason: 'the subtree must survive the gate closing');
  });
}
