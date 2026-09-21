import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/api_cache.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';
import 'package:tourism_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:tourism_mobile/features/auth/domain/auth_repository.dart';
import 'package:tourism_mobile/features/onboarding/data/session_identity_cache.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/application/route_start_block.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';

class SessionState {
  const SessionState({
    this.isHydrated = false,
    this.onboardingCompleted = false,
    this.displayName,
    this.phone,
    this.userId,
    this.accessToken,
    this.avatarUrl,
    this.coverUrl,
    this.notifyPushEnabled = true,
    this.notifySmsEnabled = false,
    this.notifyHapticsEnabled = true,
    this.travelPlusActive = false,
    this.travelPlusPlan,
    this.travelPlusExpiresAt,
    this.aiChatEnabled = true,
    this.maxRoutePoints = 12,
    this.alternativesCount = 3,
    this.advancedFiltersEnabled = true,
    this.otpConsentsRequired = true,
    this.isOffline = false,
    this.isProvisional = false,
    this.sessionExpiredNotice = false,
  });

  final bool isHydrated;
  final bool onboardingCompleted;
  final String? displayName;
  final String? phone;
  final String? userId;
  final String? accessToken;
  final String? avatarUrl;
  final String? coverUrl;
  final bool notifyPushEnabled;
  final bool notifySmsEnabled;
  final bool notifyHapticsEnabled;
  final bool travelPlusActive;
  final String? travelPlusPlan;
  final DateTime? travelPlusExpiresAt;
  final bool aiChatEnabled;
  final int maxRoutePoints;
  final int alternativesCount;
  final bool advancedFiltersEnabled;
  final bool otpConsentsRequired;

  /// True only when hydrate/refresh most recently failed with a connectivity
  /// error and the session shown is a cached fallback, not a live one — the
  /// access token may be stale or absent. Never set for an outright
  /// auth-rejection (invalid/expired refresh token).
  final bool isOffline;

  /// The session is shown from the cached identity while the real check is
  /// still running (cold start on a slow network). There is no access token
  /// yet: authenticated requests wait for the shared refresh.
  final bool isProvisional;

  /// One-shot: the refresh token was rejected at start-up, so the person is
  /// back on the welcome screen and should be told why. The screen that shows
  /// the message clears it via [SessionController.consumeSessionExpiredNotice].
  final bool sessionExpiredNotice;

  bool get isAuthenticated =>
      onboardingCompleted && (accessToken != null || userId != null);

  SessionState copyWith({
    bool? isHydrated,
    bool? onboardingCompleted,
    String? displayName,
    String? phone,
    String? userId,
    String? accessToken,
    String? avatarUrl,
    String? coverUrl,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
    bool? travelPlusActive,
    String? travelPlusPlan,
    DateTime? travelPlusExpiresAt,
    bool? aiChatEnabled,
    int? maxRoutePoints,
    int? alternativesCount,
    bool? advancedFiltersEnabled,
    bool? otpConsentsRequired,
    bool? isOffline,
    bool? isProvisional,
    bool? sessionExpiredNotice,
    bool clearAccessToken = false,
    bool clearAvatarUrl = false,
    bool clearCoverUrl = false,
    bool clearTravelPlusPlan = false,
    bool clearTravelPlusExpiresAt = false,
  }) {
    return SessionState(
      isHydrated: isHydrated ?? this.isHydrated,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      notifyPushEnabled: notifyPushEnabled ?? this.notifyPushEnabled,
      notifySmsEnabled: notifySmsEnabled ?? this.notifySmsEnabled,
      notifyHapticsEnabled: notifyHapticsEnabled ?? this.notifyHapticsEnabled,
      travelPlusActive: travelPlusActive ?? this.travelPlusActive,
      travelPlusPlan: clearTravelPlusPlan
          ? null
          : (travelPlusPlan ?? this.travelPlusPlan),
      travelPlusExpiresAt: clearTravelPlusExpiresAt
          ? null
          : (travelPlusExpiresAt ?? this.travelPlusExpiresAt),
      aiChatEnabled: aiChatEnabled ?? this.aiChatEnabled,
      maxRoutePoints: maxRoutePoints ?? this.maxRoutePoints,
      alternativesCount: alternativesCount ?? this.alternativesCount,
      advancedFiltersEnabled:
          advancedFiltersEnabled ?? this.advancedFiltersEnabled,
      otpConsentsRequired: otpConsentsRequired ?? this.otpConsentsRequired,
      isOffline: isOffline ?? this.isOffline,
      isProvisional: isProvisional ?? this.isProvisional,
      sessionExpiredNotice: sessionExpiredNotice ?? this.sessionExpiredNotice,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required AuthRepository authRepository,
    required SecureStoragePort secureStorage,
    required this.useMockData,
    SessionIdentityCache? identityCache,
    this.onSessionCleared,
    SessionState? initial,
  }) : _auth = authRepository,
       _storage = secureStorage,
       _identityCache = identityCache ?? MemorySessionIdentityCache(),
       super(initial ?? const SessionState());

  final AuthRepository _auth;
  final SecureStoragePort _storage;
  final SessionIdentityCache _identityCache;
  final bool useMockData;
  final FutureOr<void> Function()? onSessionCleared;
  Future<String?>? _refreshInFlight;
  Future<OtpStartResult>? _otpRequestInFlight;

  void saveIdentity({String? displayName, required String phone}) {
    final normalizedName = displayName?.trim();
    state = state.copyWith(
      displayName: normalizedName?.isNotEmpty == true ? normalizedName : null,
      phone: phone.trim(),
    );
  }

  Future<OtpStartResult> requestOtp({String? displayName}) async {
    final existing = _otpRequestInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _requestOtpInternal(displayName: displayName);
    _otpRequestInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_otpRequestInFlight, future)) {
        _otpRequestInFlight = null;
      }
    }
  }

  Future<OtpStartResult> _requestOtpInternal({String? displayName}) async {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : state.displayName?.trim();
    final phone = state.phone?.trim();
    if (phone == null || phone.isEmpty) {
      throw const AuthFailure('Телефон обязателен');
    }
    final result = await _auth.requestOtp(
      displayName: name?.isNotEmpty == true ? name : null,
      phone: phone,
    );
    state = state.copyWith(
      displayName: name?.isNotEmpty == true ? name : null,
      otpConsentsRequired: result.consentsRequired,
    );
    return result;
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
      final tokens = await _auth.verifyOtp(
        phone: phone,
        code: code,
        privacyAccepted: privacyAccepted,
        personalDataAccepted: personalDataAccepted,
      );
      final me = await _auth.getMe(tokens.accessToken);
      state = state.copyWith(
        isHydrated: true,
        onboardingCompleted: true,
        displayName: name?.isNotEmpty == true ? name : me.displayName,
        phone: me.phone,
        userId: me.id,
        accessToken: tokens.accessToken,
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
      isOffline: false,
      displayName: me.displayName,
      phone: me.phone,
      userId: me.id,
      accessToken: tokens.accessToken,
      avatarUrl: me.avatarUrl,
      coverUrl: me.coverUrl,
      notifyPushEnabled: me.notifyPushEnabled,
      notifySmsEnabled: me.notifySmsEnabled,
      notifyHapticsEnabled: me.notifyHapticsEnabled,
      travelPlusActive: me.travelPlusActive,
      travelPlusPlan: me.travelPlusPlan,
      travelPlusExpiresAt: me.travelPlusExpiresAt,
      aiChatEnabled: me.aiChatEnabled,
      maxRoutePoints: me.maxRoutePoints,
      alternativesCount: me.alternativesCount,
      advancedFiltersEnabled: me.advancedFiltersEnabled,
    );
    unawaited(_cacheIdentity(me));
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

  Future<void> updateDisplayName(String displayName) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.patchMe(
      accessToken: token,
      displayName: displayName.trim(),
    );
    _applyMe(me);
  }

  Future<void> updateNotificationPrefs({
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  }) async {
    final token = state.accessToken;
    if (token == null) {
      // Local/mock preview without a session — keep toggles responsive.
      state = state.copyWith(
        notifyPushEnabled: notifyPushEnabled,
        notifySmsEnabled: notifySmsEnabled,
        notifyHapticsEnabled: notifyHapticsEnabled,
      );
      return;
    }
    final me = await _auth.patchMe(
      accessToken: token,
      notifyPushEnabled: notifyPushEnabled,
      notifySmsEnabled: notifySmsEnabled,
      notifyHapticsEnabled: notifyHapticsEnabled,
    );
    _applyMe(me);
  }

  Future<void> requestPhoneChange(String phone) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    await _auth.requestPhoneChange(accessToken: token, phone: phone.trim());
  }

  Future<void> verifyPhoneChange({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  }) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.verifyPhoneChange(
      accessToken: token,
      phone: phone.trim(),
      code: code,
      privacyAccepted: privacyAccepted,
      personalDataAccepted: personalDataAccepted,
    );
    _applyMe(me);
  }

  Future<void> uploadAvatar(String filePath) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.uploadAvatar(accessToken: token, filePath: filePath);
    _applyMe(me);
  }

  Future<void> uploadCover(String filePath) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.uploadCover(accessToken: token, filePath: filePath);
    _applyMe(me);
  }

  void _applyMe(MeProfile me) {
    state = state.copyWith(
      displayName: me.displayName,
      phone: me.phone,
      userId: me.id,
      avatarUrl: me.avatarUrl,
      coverUrl: me.coverUrl,
      notifyPushEnabled: me.notifyPushEnabled,
      notifySmsEnabled: me.notifySmsEnabled,
      notifyHapticsEnabled: me.notifyHapticsEnabled,
      travelPlusActive: me.travelPlusActive,
      travelPlusPlan: me.travelPlusPlan,
      travelPlusExpiresAt: me.travelPlusExpiresAt,
      aiChatEnabled: me.aiChatEnabled,
      maxRoutePoints: me.maxRoutePoints,
      alternativesCount: me.alternativesCount,
      advancedFiltersEnabled: me.advancedFiltersEnabled,
      clearAvatarUrl: me.avatarUrl == null,
      clearCoverUrl: me.coverUrl == null,
      clearTravelPlusPlan: me.travelPlusPlan == null,
      clearTravelPlusExpiresAt: me.travelPlusExpiresAt == null,
    );
    unawaited(_cacheIdentity(me));
  }

  /// Best-effort: a failure to write the offline fallback cache must never
  /// surface as an error on the caller's live, successful request.
  Future<void> _cacheIdentity(MeProfile me) async {
    try {
      await _identityCache.save(
        CachedIdentity(
          userId: me.id,
          displayName: me.displayName,
          phone: me.phone,
          avatarUrl: me.avatarUrl,
          coverUrl: me.coverUrl,
        ),
      );
    } on Object {
      // Ignore — this cache only matters for a future offline cold start.
    }
  }

  Future<void> activateTravelPlus({required bool yearly}) async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.activateTravelPlus(
      accessToken: token,
      plan: yearly ? 'yearly' : 'monthly',
    );
    _applyMe(me);
  }

  Future<void> cancelTravelPlus() async {
    final token = state.accessToken;
    if (token == null) {
      throw const AuthFailure('Нужна авторизация');
    }
    final me = await _auth.cancelTravelPlus(accessToken: token);
    _applyMe(me);
  }

  Future<void> hydrate() async {
    if (state.isHydrated) {
      return;
    }
    // Same single-flight as a 401 retry: with rotating refresh tokens a second
    // concurrent refresh of the same token reads as theft and revokes the
    // whole token family, so hydrate and the interceptor must never race.
    await refreshAccessToken();
  }

  /// Shows the session from the cached identity while [hydrate] is still
  /// running, so a slow network does not keep the person on the preloader.
  /// Returns false when there is nothing to show (no stored token or cache).
  Future<bool> enterProvisional() async {
    if (state.isHydrated) {
      return false;
    }
    if (state.isProvisional) {
      return true;
    }
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      return false;
    }
    final cached = await _identityCache.read();
    // hydrate may have finished while the cache was being read.
    if (cached == null || state.isHydrated) {
      return false;
    }
    state = state.copyWith(
      onboardingCompleted: true,
      isProvisional: true,
      isOffline: false,
      displayName: cached.displayName,
      phone: cached.phone,
      userId: cached.userId,
      avatarUrl: cached.avatarUrl,
      coverUrl: cached.coverUrl,
      clearAvatarUrl: cached.avatarUrl == null,
      clearCoverUrl: cached.coverUrl == null,
    );
    return true;
  }

  void consumeSessionExpiredNotice() {
    if (state.sessionExpiredNotice) {
      state = state.copyWith(sessionExpiredNotice: false);
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

  /// One code path for start-up and mid-session refreshes. While the session
  /// is not hydrated yet this also loads the profile and finishes the start-up.
  ///
  /// Only an outright 401/403 from the refresh endpoint means the token was
  /// rejected. Everything else (no network, 5xx, 429, a timeout, a parse
  /// error) is a transient problem: the token stays and the session falls back
  /// to the cached identity instead of logging the person out.
  Future<String?> _refreshAccessTokenInternal() async {
    final startingUp = !state.isHydrated;
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      if (startingUp) {
        state = state.copyWith(isHydrated: true, isProvisional: false);
        return null;
      }
      await clearSession();
      return null;
    }
    final AuthTokens tokens;
    try {
      tokens = await _auth.refresh(refresh);
    } on AuthFailure {
      await clearSession(sessionExpired: true);
      return null;
    } on Object {
      if (startingUp) {
        await _startFromCache();
      } else {
        state = state.copyWith(isOffline: true);
      }
      return null;
    }
    await _storage.write(
      key: SecureStorageKeys.refreshToken,
      value: tokens.refreshToken,
    );
    if (!startingUp) {
      state = state.copyWith(accessToken: tokens.accessToken, isOffline: false);
      return tokens.accessToken;
    }
    try {
      final me = await _auth.getMe(tokens.accessToken);
      state = state.copyWith(
        isHydrated: true,
        isProvisional: false,
        onboardingCompleted: true,
        isOffline: false,
        accessToken: tokens.accessToken,
      );
      _applyMe(me);
    } on Object {
      // The token was rotated and saved above; only the profile is missing.
      await _startFromCache(accessToken: tokens.accessToken);
    }
    return tokens.accessToken;
  }

  /// Start-up without a live answer: use the identity cached by the last
  /// successful getMe(). A missing access token is fine — every live call has
  /// its own NetworkFailure handling and the offline stores work from cached
  /// data regardless. With no cache there is nothing to describe, so the
  /// person lands on the welcome screen as a guest; the stored token is kept
  /// for the next start.
  Future<void> _startFromCache({String? accessToken}) async {
    final cached = await _identityCache.read();
    if (cached == null) {
      state = const SessionState(isHydrated: true);
      return;
    }
    state = state.copyWith(
      isHydrated: true,
      isProvisional: false,
      onboardingCompleted: true,
      isOffline: true,
      accessToken: accessToken,
      displayName: cached.displayName,
      phone: cached.phone,
      userId: cached.userId,
      avatarUrl: cached.avatarUrl,
      coverUrl: cached.coverUrl,
      clearAvatarUrl: cached.avatarUrl == null,
      clearCoverUrl: cached.coverUrl == null,
    );
  }

  Future<void> clearSession({bool sessionExpired = false}) async {
    final refresh = await _storage.read(key: SecureStorageKeys.refreshToken);
    if (refresh != null && !useMockData) {
      try {
        await _auth.logout(refresh);
      } on Object {
        // Best-effort revoke.
      }
    }
    await _storage.delete(key: SecureStorageKeys.refreshToken);
    try {
      await _identityCache.clear();
    } on Object {
      // Best-effort; the token deletion above is what actually matters.
    }
    state = SessionState(
      isHydrated: true,
      sessionExpiredNotice: sessionExpired,
    );
    await onSessionCleared?.call();
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

final sessionIdentityCacheProvider = Provider<SessionIdentityCache>((ref) {
  return SharedPreferencesSessionIdentityCache();
});

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  final cacheRegistry = ref.watch(apiCacheRegistryProvider);
  final controller = SessionController(
    authRepository: ref.watch(authRepositoryProvider),
    secureStorage: ref.watch(secureStorageProvider),
    useMockData: ref.watch(appConfigProvider).useMockData,
    identityCache: ref.watch(sessionIdentityCacheProvider),
    onSessionCleared: () async {
      cacheRegistry.invalidateAll();
      // The start block belongs to the account that just left.
      unawaited(ref.read(routeStartBlockStoreProvider).clear());
      // Offline snapshots may contain private/user-created route data. Do
      // not leave the previous account's content available after logout.
      try {
        await clearOfflineRouteData(
          ref.read(offlineRouteStoreProvider),
          executionStore: ref.read(routeExecutionOfflineStoreProvider),
        );
      } on Object {
        // Token deletion and session reset still win if local cleanup fails.
      }
      // The route draft belongs to the account that left: stop any send in
      // flight (it must not run under the next account) and erase the copy.
      try {
        final drafts = ref.read(routeDraftSyncServiceProvider);
        drafts.cancel();
        await drafts.discardLocal();
        await drafts.clearSignOutFlag();
      } on Object {
        // finishInterruptedSignOut() retries at the next start.
      }
    },
  );
  unawaited(controller.hydrate());
  return controller;
});
