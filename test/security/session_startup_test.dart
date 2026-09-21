import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/data/session_identity_cache.dart';

/// Refresh and getMe are scripted; anything else is a bug in the test.
class _ScriptedAuth implements AuthRepository {
  _ScriptedAuth({this.refreshBehaviour, this.getMeBehaviour});

  Future<AuthTokens> Function(String refreshToken)? refreshBehaviour;
  Future<MeProfile> Function(String accessToken)? getMeBehaviour;
  final refreshCalls = <String>[];
  var logoutCalls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    refreshCalls.add(refreshToken);
    final behaviour = refreshBehaviour;
    if (behaviour == null) {
      return Future.value(
        AuthTokens(
          accessToken: 'access-${refreshCalls.length}',
          refreshToken: 'refresh-${refreshCalls.length + 1}',
          expiresIn: 900,
        ),
      );
    }
    return behaviour(refreshToken);
  }

  @override
  Future<MeProfile> getMe(String accessToken) {
    final behaviour = getMeBehaviour;
    if (behaviour == null) {
      return Future.value(
        const MeProfile(id: 'user-1', displayName: 'Никита', phone: '+7900'),
      );
    }
    return behaviour(accessToken);
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<
  ({
    SessionController controller,
    MemorySecureStorage storage,
    MemorySessionIdentityCache cache,
    List<String> events,
  })
>
_setup(_ScriptedAuth auth, {bool token = true, bool cached = true}) async {
  final storage = MemorySecureStorage();
  if (token) {
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'refresh-1',
    );
  }
  final cache = MemorySessionIdentityCache();
  if (cached) {
    await cache.save(
      const CachedIdentity(
        userId: 'user-1',
        displayName: 'Кэш',
        phone: '+7900',
      ),
    );
  }
  final events = <String>[];
  final controller = SessionController(
    authRepository: auth,
    secureStorage: storage,
    identityCache: cache,
    useMockData: false,
    onSessionCleared: () => events.add('cleared'),
  );
  return (
    controller: controller,
    storage: storage,
    cache: cache,
    events: events,
  );
}

void main() {
  group('start-up refresh', () {
    test('a rejected refresh token (401/403) signs out, cleans up and leaves '
        'a one-shot notice', () async {
      final auth = _ScriptedAuth(
        refreshBehaviour: (_) => throw const AuthFailure('nope'),
      );
      final s = await _setup(auth);

      await s.controller.hydrate();

      expect(s.controller.state.isHydrated, isTrue);
      expect(s.controller.state.isAuthenticated, isFalse);
      expect(s.controller.state.sessionExpiredNotice, isTrue);
      expect(await s.storage.read(key: SecureStorageKeys.refreshToken), isNull);
      expect(await s.cache.read(), isNull);
      expect(s.events, ['cleared']);

      s.controller.consumeSessionExpiredNotice();
      expect(s.controller.state.sessionExpiredNotice, isFalse);
    });

    for (final failure in <AppFailure>[
      const UnexpectedFailure('HTTP 503'),
      const UnexpectedFailure('HTTP 429'),
      const NetworkFailure(),
    ]) {
      test('a transient ${failure.runtimeType} keeps the token and starts '
          'from the cached identity', () async {
        final auth = _ScriptedAuth(refreshBehaviour: (_) => throw failure);
        final s = await _setup(auth);

        await s.controller.hydrate();

        expect(s.controller.state.isHydrated, isTrue);
        expect(s.controller.state.isAuthenticated, isTrue);
        expect(s.controller.state.isOffline, isTrue);
        expect(s.controller.state.userId, 'user-1');
        expect(s.controller.state.sessionExpiredNotice, isFalse);
        expect(
          await s.storage.read(key: SecureStorageKeys.refreshToken),
          'refresh-1',
        );
        expect(s.events, isEmpty);
      });
    }

    test('a failing getMe after a good refresh keeps the rotated token and '
        'the fresh access token', () async {
      final auth = _ScriptedAuth(
        getMeBehaviour: (_) => throw const UnexpectedFailure('HTTP 500'),
      );
      final s = await _setup(auth);

      await s.controller.hydrate();

      expect(s.controller.state.isAuthenticated, isTrue);
      expect(s.controller.state.isOffline, isTrue);
      expect(s.controller.state.accessToken, 'access-1');
      expect(
        await s.storage.read(key: SecureStorageKeys.refreshToken),
        'refresh-2',
      );
    });

    test('hydrate and a 401-triggered refresh share one refresh call '
        '(rotating tokens revoke the family on reuse)', () async {
      final gate = Completer<AuthTokens>();
      final auth = _ScriptedAuth(refreshBehaviour: (_) => gate.future);
      final s = await _setup(auth);

      final hydrating = s.controller.hydrate();
      final retry = s.controller.refreshAccessToken();
      await Future<void>.delayed(Duration.zero);
      gate.complete(
        const AuthTokens(
          accessToken: 'access-x',
          refreshToken: 'refresh-x',
          expiresIn: 900,
        ),
      );

      expect(await retry, 'access-x');
      await hydrating;
      expect(auth.refreshCalls, ['refresh-1']);
      expect(s.controller.state.isHydrated, isTrue);
      expect(s.controller.state.userId, 'user-1');
      expect(s.controller.state.accessToken, 'access-x');
    });

    test(
      'no stored token: hydrate makes a guest without any request',
      () async {
        final auth = _ScriptedAuth();
        final s = await _setup(auth, token: false);

        await s.controller.hydrate();

        expect(s.controller.state.isHydrated, isTrue);
        expect(s.controller.state.isAuthenticated, isFalse);
        expect(s.controller.state.sessionExpiredNotice, isFalse);
        expect(auth.refreshCalls, isEmpty);
      },
    );
  });

  group('provisional session', () {
    test('shows the cached identity while the refresh is still running and '
        'is replaced by the real session', () async {
      final gate = Completer<AuthTokens>();
      final auth = _ScriptedAuth(refreshBehaviour: (_) => gate.future);
      final s = await _setup(auth);

      final hydrating = s.controller.hydrate();
      await Future<void>.delayed(Duration.zero);
      expect(await s.controller.enterProvisional(), isTrue);

      expect(s.controller.state.isProvisional, isTrue);
      expect(s.controller.state.isHydrated, isFalse);
      expect(s.controller.state.isAuthenticated, isTrue);
      expect(s.controller.state.accessToken, isNull);
      expect(s.controller.state.displayName, 'Кэш');

      gate.complete(
        const AuthTokens(
          accessToken: 'access-x',
          refreshToken: 'refresh-x',
          expiresIn: 900,
        ),
      );
      await hydrating;

      expect(s.controller.state.isProvisional, isFalse);
      expect(s.controller.state.isHydrated, isTrue);
      expect(s.controller.state.accessToken, 'access-x');
      expect(s.controller.state.displayName, 'Никита');
    });

    test(
      'a rejected token while provisional signs out with the notice',
      () async {
        final gate = Completer<AuthTokens>();
        final auth = _ScriptedAuth(refreshBehaviour: (_) => gate.future);
        final s = await _setup(auth);

        final hydrating = s.controller.hydrate();
        await Future<void>.delayed(Duration.zero);
        await s.controller.enterProvisional();
        gate.completeError(const AuthFailure('revoked'));
        await hydrating;

        expect(s.controller.state.isAuthenticated, isFalse);
        expect(s.controller.state.isProvisional, isFalse);
        expect(s.controller.state.sessionExpiredNotice, isTrue);
        expect(s.events, ['cleared']);
      },
    );

    test(
      'nothing to show without a cached identity or a stored token',
      () async {
        final noCache = await _setup(
          _ScriptedAuth(
            refreshBehaviour: (_) => Completer<AuthTokens>().future,
          ),
          cached: false,
        );
        expect(await noCache.controller.enterProvisional(), isFalse);
        expect(noCache.controller.state.isProvisional, isFalse);

        final noToken = await _setup(_ScriptedAuth(), token: false);
        expect(await noToken.controller.enterProvisional(), isFalse);
      },
    );
  });

  group('mid-session refresh', () {
    test(
      'a 5xx keeps the session; a 401/403 ends it with the notice',
      () async {
        final auth = _ScriptedAuth(
          refreshBehaviour: (_) => throw const UnexpectedFailure('HTTP 500'),
        );
        final s = await _setup(auth);
        s.controller.state = const SessionState(
          isHydrated: true,
          onboardingCompleted: true,
          userId: 'user-1',
          accessToken: 'old',
        );

        expect(await s.controller.refreshAccessToken(), isNull);
        expect(s.controller.state.isAuthenticated, isTrue);
        expect(s.controller.state.accessToken, 'old');
        expect(
          await s.storage.read(key: SecureStorageKeys.refreshToken),
          'refresh-1',
        );

        auth.refreshBehaviour = (_) => throw const AuthFailure('revoked');
        expect(await s.controller.refreshAccessToken(), isNull);
        expect(s.controller.state.isAuthenticated, isFalse);
        expect(s.controller.state.sessionExpiredNotice, isTrue);
      },
    );
  });
}
