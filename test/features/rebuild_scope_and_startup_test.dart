import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_swipe_deck.dart';
import 'package:tourism_mobile/features/search/application/search_history_provider.dart';

import '../support/test_overrides.dart';

class _ProbeSession extends SessionController {
  _ProbeSession({
    required super.authRepository,
    required super.secureStorage,
    required super.useMockData,
    super.initial,
  });

  void rotateAccessToken() {
    state = state.copyWith(accessToken: 'rotated-${state.accessToken}');
  }

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }
}

const _seaRoute = RouteSummary(
  id: 'sea',
  name: 'Море и сосны',
  slug: 'sea',
  shortDescription: 'Береговая тропа у бухты',
  stopsCount: 2,
  coverImageUrl: 'https://localhost:8000/media/sea.jpg',
);

const _mountainRoute = RouteSummary(
  id: 'mountain',
  name: 'Подъем на Ай-Петри',
  slug: 'mountain',
  shortDescription: 'Горный маршрут',
  stopsCount: 3,
  coverImageUrl: 'https://localhost:8000/media/mountain.jpg',
);

const _forestRoute = RouteSummary(
  id: 'forest',
  name: 'Лесная тропа',
  slug: 'forest',
  shortDescription: 'Тенистый маршрут',
  stopsCount: 4,
  coverImageUrl: 'https://localhost:8000/media/forest.jpg',
);

(_ProbeSession, List<Override>) _mutableSession() {
  final storage = MemorySecureStorage();
  final auth = MockAuthRepository();
  final controller = _ProbeSession(
    authRepository: auth,
    secureStorage: storage,
    useMockData: true,
    initial: const SessionState(
      isHydrated: true,
      onboardingCompleted: true,
      displayName: 'Никита',
      phone: '+79001234567',
      userId: 'mock-user',
      accessToken: 'mock-access',
    ),
  );
  return (
    controller,
    [
      appConfigProvider.overrideWithValue(testAppConfig),
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(auth),
      sessionProvider.overrideWith((ref) => controller),
      searchHistoryStoreProvider.overrideWithValue(MemorySearchHistoryStore()),
    ],
  );
}

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.light, home: home);
}

void main() {
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
  });

  test('main does not await push bootstrap before first frame', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('await AppPush.bootstrap()'), isFalse);
    final runAppAt = src.indexOf('runApp(');
    final bootstrapAt = src.indexOf('AppPush.bootstrap()');
    expect(runAppAt, greaterThanOrEqualTo(0));
    expect(bootstrapAt, greaterThan(runAppAt));
    expect(src.contains('addPostFrameCallback'), isTrue);
  });

  test('app shell selects session userId', () {
    final src = File(
      'lib/routing/shell/app_shell_screen.dart',
    ).readAsStringSync();
    expect(src.contains('sessionProvider.select((s) => s.userId)'), isTrue);
    expect(src.contains('ref.watch(sessionProvider).userId'), isFalse);
  });

  testWidgets('token refresh does not rebuild route hero cards', (
    tester,
  ) async {
    final (session, overrides) = _mutableSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: _app(
          const Scaffold(
            body: SizedBox(
              width: 361,
              child: RouteHeroCard(route: _seaRoute, interactive: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var heroRebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is RouteHeroCard) {
        heroRebuilds += 1;
      }
    };

    session.rotateAccessToken();
    await tester.pump();
    expect(heroRebuilds, 0);

    session.setDisplayName('Мария');
    await tester.pump();
    expect(heroRebuilds, greaterThan(0));
  });

  testWidgets('token refresh does not rebuild Home greeting', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final (session, overrides) = _mutableSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: _app(const Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Привет, Никита'), findsOneWidget);

    var homeRebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is HomeScreen) {
        homeRebuilds += 1;
      }
    };

    session.rotateAccessToken();
    await tester.pump();
    expect(homeRebuilds, 0);
    expect(find.textContaining('Привет, Никита'), findsOneWidget);

    session.setDisplayName('Мария');
    await tester.pump();
    expect(homeRebuilds, greaterThan(0));
    expect(find.textContaining('Привет, Мария'), findsOneWidget);
  });

  testWidgets('swipe progress does not rebuild cached route covers', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    Widget deck(double progress) {
      return ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: _app(
          Scaffold(
            body: RouteSwipeDeck(
              routes: const [_seaRoute, _mountainRoute, _forestRoute],
              onSwipe: (_, _) {},
              debugProgress: progress,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(deck(0));
    await tester.pump();

    const coverKey = ValueKey<String>('route-cover-sea');
    expect(find.byKey(coverKey), findsOneWidget);
    final coverElement = tester.element(find.byKey(coverKey));

    var coverRebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (identical(element, coverElement)) {
        coverRebuilds += 1;
      }
    };

    await tester.pumpWidget(deck(0.45));
    await tester.pump();

    expect(find.byKey(coverKey), findsOneWidget);
    expect(coverRebuilds, 0);
  });
}
