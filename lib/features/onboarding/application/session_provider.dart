import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';

class SessionState {
  const SessionState({
    this.isHydrated = false,
    this.onboardingCompleted = false,
    this.displayName,
    this.phone,
    this.userId,
    this.accessToken,
  });

  final bool isHydrated;
  final bool onboardingCompleted;
  final String? displayName;
  final String? phone;
  final String? userId;
  final String? accessToken;

  bool get isAuthenticated =>
      onboardingCompleted && (accessToken != null || userId != null);

  SessionState copyWith({
    bool? isHydrated,
    bool? onboardingCompleted,
    String? displayName,
    String? phone,
    String? userId,
    String? accessToken,
    bool clearAccessToken = false,
  }) {
    return SessionState(
      isHydrated: isHydrated ?? this.isHydrated,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required AuthRepository authRepository,
    required SecureStoragePort secureStorage,
    required this.useMockData,
    SessionState? initial,
  }) : _auth = authRepository,
       _storage = secureStorage,
       super(initial ?? const SessionState());

  final AuthRepository _auth;
  final SecureStoragePort _storage;
  final bool useMockData;
  Future<String?>? _refreshInFlight;

  void saveIdentity({required String displayName, required String phone}) {
    state = state.copyWith(
      displayName: displayName.trim(),
      phone: phone.trim(),
    );
  }

  Future<void> requestOtp() async {
    final name = state.displayName?.trim();
    final phone = state.phone?.trim();
    if (name == null || name.isEmpty || phone == null || phone.isEmpty) {
      throw const AuthFailure('Имя и телефон обязательны');
    }
    await _auth.requestOtp(displayName: name, phone: phone);
  }

  Future<void> verifyOtp({
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) async {
    final phone = state.phone?.trim();
    final name = state.displayName?.trim();
    if (phone == null || phone.isEmpty) {
      throw const AuthFailure('Телефон обязателен');
    }
    if (useMockData) {
      await _auth.verifyOtp(
        phone: phone,
        code: code,
        privacyAccepted: privacyAccepted,
        personalDataAccepted: personalDataAccepted,
      );
      state = state.copyWith(
        isHydrated: true,
        onboardingCompleted: true,
        displayName: name,
        phone: phone,
        userId: 'mock-user',
        accessToken: 'mock-access',
      );
      await _storage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'mock-refresh',
      );
      return;
    }

    final tokens = await _auth.verifyOtp(
      phone: phone,
      code: code,
      privacyAccepted: privacyAccepted,
      personalDataAccepted: personalDataAccepted,
    );
    await _storage.write(
      key: SecureStorageKeys.refreshToken,
      value: tokens.refreshToken,
    );
    final me = await _auth.getMe(tokens.accessToken);
    state = state.copyWith(
      isHydrated: true,
      onboardingCompleted: true,
      displayName: me.displayName,
      phone: me.phone,
      userId: me.id,
      accessToken: tokens.accessToken,
    );
  }

  /// Mock OTP accept — no network. Kept for tests that call completeOnboarding.
  void completeOnboarding({String? displayName}) {
    state = state.copyWith(
      isHydrated: true,
      onboardingCompleted: true,
      displayName: displayName?.trim() ?? state.displayName,
      accessToken: state.accessToken ?? 'mock-access',
      userId: state.userId ?? 'mock-user',
    );
  }

  Future<void> hydrate() async {
    if (state.isHydrated) {
      return;
    }
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      state = state.copyWith(isHydrated: true);
      return;
    }
    try {
      final tokens = await _auth.refresh(refresh);
      await _storage.write(
        key: SecureStorageKeys.refreshToken,
        value: tokens.refreshToken,
      );
      final me = await _auth.getMe(tokens.accessToken);
      state = state.copyWith(
        isHydrated: true,
        onboardingCompleted: true,
        displayName: me.displayName,
        phone: me.phone,
        userId: me.id,
        accessToken: tokens.accessToken,
      );
    } on Object {
      await _storage.delete(key: SecureStorageKeys.refreshToken);
      state = const SessionState(isHydrated: true);
    }
  }

  Future<String?> refreshAccessToken() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _refreshAccessTokenInternal();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<String?> _refreshAccessTokenInternal() async {
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      await clearSession();
      return null;
    }
    try {
      final tokens = await _auth.refresh(refresh);
      await _storage.write(
        key: SecureStorageKeys.refreshToken,
        value: tokens.refreshToken,
      );
      state = state.copyWith(accessToken: tokens.accessToken);
      return tokens.accessToken;
    } on Object {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh != null && !useMockData) {
      try {
        await _auth.logout(refresh);
      } on Object {
        // Best-effort revoke.
      }
    }
    await _storage.delete(key: SecureStorageKeys.refreshToken);
    state = const SessionState(isHydrated: true);
  }

  void resetOnboarding() {
    unawaited(clearSession());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockAuthRepository();
  }
  // Raw Dio without auth interceptor to avoid refresh loops.
  final dio = ref.watch(rawDioProvider);
  return ApiAuthRepository(dio);
});

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  final controller = SessionController(
    authRepository: ref.watch(authRepositoryProvider),
    secureStorage: ref.watch(secureStorageProvider),
    useMockData: ref.watch(appConfigProvider).useMockData,
  );
  unawaited(controller.hydrate());
  return controller;
});
