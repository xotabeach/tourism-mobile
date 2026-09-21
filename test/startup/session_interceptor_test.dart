import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/app_version_headers.dart';
import 'package:tourism_mobile/core/storage/memory_secure_storage.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/onboarding/data/session_identity_cache.dart';
import 'package:tourism_mobile/features/settings/application/motion_preference.dart';

import '../support/test_overrides.dart';

class _GatedAuth implements AuthRepository {
  final release = Completer<AuthTokens>();
  var refreshCalls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    refreshCalls++;
    return release.future;
  }

  @override
  Future<MeProfile> getMe(String accessToken) async =>
      const MeProfile(id: 'user-1', displayName: 'Никита', phone: '+7900');

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Capture extends Interceptor {
  final seen = <Map<String, dynamic>>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    seen.add(Map.of(options.headers));
    handler.resolve(Response<void>(requestOptions: options, statusCode: 200));
  }
}

void main() {
  test('while the session is provisional, authenticated requests wait for the '
      'start-up refresh instead of going out without a token', () async {
    final auth = _GatedAuth();
    final storage = MemorySecureStorage();
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'refresh-1',
    );
    final cache = MemorySessionIdentityCache();
    await cache.save(const CachedIdentity(userId: 'user-1'));
    final controller = SessionController(
      authRepository: auth,
      secureStorage: storage,
      identityCache: cache,
      useMockData: false,
    );
    final container = ProviderContainer(
      overrides: [
        ...testSessionOverrides(),
        appVersionHeadersLoaderProvider.overrideWithValue(() async => {}),
        sessionProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);

    final hydrating = controller.hydrate();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.enterProvisional(), isTrue);
    expect(controller.state.accessToken, isNull);

    final dio = container.read(dioProvider);
    final capture = _Capture();
    dio.interceptors.add(capture);
    final request = dio.get<void>('/api/v1/me/notifications');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(capture.seen, isEmpty, reason: 'must not be sent without a token');

    auth.release.complete(
      const AuthTokens(
        accessToken: 'access-x',
        refreshToken: 'refresh-x',
        expiresIn: 900,
      ),
    );
    await request;
    await hydrating;

    expect(capture.seen.single['Authorization'], 'Bearer access-x');
    expect(auth.refreshCalls, 1, reason: 'one shared refresh, not two');
  });

  test('auth endpoints never wait on the start-up refresh', () async {
    final auth = _GatedAuth();
    final storage = MemorySecureStorage();
    await storage.write(
      key: SecureStorageKeys.refreshToken,
      value: 'refresh-1',
    );
    final cache = MemorySessionIdentityCache();
    await cache.save(const CachedIdentity(userId: 'user-1'));
    final controller = SessionController(
      authRepository: auth,
      secureStorage: storage,
      identityCache: cache,
      useMockData: false,
    );
    final container = ProviderContainer(
      overrides: [
        ...testSessionOverrides(),
        appVersionHeadersLoaderProvider.overrideWithValue(() async => {}),
        sessionProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);
    final hydrating = controller.hydrate();
    await Future<void>.delayed(Duration.zero);
    await controller.enterProvisional();

    final dio = container.read(dioProvider);
    final capture = _Capture();
    dio.interceptors.add(capture);
    await dio.post<void>('/api/v1/auth/otp/request');

    expect(capture.seen, hasLength(1));
    auth.release.complete(
      const AuthTokens(accessToken: 'a', refreshToken: 'r', expiresIn: 900),
    );
    await hydrating;
  });

  test(
    'the saved "less motion" setting is applied before the first frame',
    () async {
      addTearDown(() => AppMotion.reduceMotion = false);
      SharedPreferences.setMockInitialValues({'settings.reduce_motion': true});
      AppMotion.reduceMotion = false;

      await MotionPreferenceController.preload();

      expect(AppMotion.reduceMotion, isTrue);
    },
  );
}
