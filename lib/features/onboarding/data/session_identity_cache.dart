import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last-known profile fields, cached purely so a cold start with no
/// connectivity can still show *something* instead of forcing a logout.
/// Never a substitute for a real session — no tokens live here.
class CachedIdentity {
  const CachedIdentity({
    required this.userId,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.coverUrl,
  });

  final String userId;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final String? coverUrl;
}

abstract interface class SessionIdentityCache {
  Future<CachedIdentity?> read();

  Future<void> save(CachedIdentity identity);

  Future<void> clear();
}

/// Small, versioned JSON store — same convention as
/// SharedPreferencesOfflineRouteStore. Profile display fields only, never
/// tokens; those stay in secure storage.
final class SharedPreferencesSessionIdentityCache
    implements SessionIdentityCache {
  SharedPreferencesSessionIdentityCache({
    Future<SharedPreferences> Function()? loader,
  }) : _loader = loader ?? SharedPreferences.getInstance;

  static const _key = 'crimeatrip.session.cached_identity';
  static const _version = 1;

  final Future<SharedPreferences> Function() _loader;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs async => _prefsFuture ??= _loader();

  @override
  Future<CachedIdentity?> read() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != _version) {
        return null;
      }
      final userId = decoded['user_id'];
      if (userId is! String) {
        return null;
      }
      return CachedIdentity(
        userId: userId,
        displayName: decoded['display_name'] as String?,
        phone: decoded['phone'] as String?,
        avatarUrl: decoded['avatar_url'] as String?,
        coverUrl: decoded['cover_url'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(CachedIdentity identity) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key,
      jsonEncode({
        'version': _version,
        'user_id': identity.userId,
        'display_name': identity.displayName,
        'phone': identity.phone,
        'avatar_url': identity.avatarUrl,
        'cover_url': identity.coverUrl,
      }),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_key);
  }
}

final class MemorySessionIdentityCache implements SessionIdentityCache {
  CachedIdentity? _identity;

  @override
  Future<CachedIdentity?> read() async => _identity;

  @override
  Future<void> save(CachedIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<void> clear() async {
    _identity = null;
  }
}
