import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/routes/domain/route.dart';

/// Last-known "Мои маршруты" list, cached so the own-profile screen has
/// something to show offline. Same versioned-JSON convention as
/// SharedPreferencesOfflineRouteStore.
abstract interface class OfflineOwnRoutesCache {
  Future<List<RouteSummary>?> read();

  Future<void> save(List<RouteSummary> routes);

  Future<void> clear();
}

final class SharedPreferencesOfflineOwnRoutesCache
    implements OfflineOwnRoutesCache {
  SharedPreferencesOfflineOwnRoutesCache({
    Future<SharedPreferences> Function()? loader,
  }) : _loader = loader ?? SharedPreferences.getInstance;

  static const _key = 'crimeatrip.profile.own_routes_cache';
  static const _version = 1;

  final Future<SharedPreferences> Function() _loader;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs async => _prefsFuture ??= _loader();

  @override
  Future<List<RouteSummary>?> read() async {
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
      final items = decoded['items'];
      if (items is! List) {
        return null;
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(RouteSummary.fromJson)
          .toList();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(List<RouteSummary> routes) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key,
      jsonEncode({
        'version': _version,
        'items': routes.map((route) => route.toJson()).toList(),
      }),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_key);
  }
}

final class MemoryOfflineOwnRoutesCache implements OfflineOwnRoutesCache {
  List<RouteSummary>? _routes;

  @override
  Future<List<RouteSummary>?> read() async => _routes;

  @override
  Future<void> save(List<RouteSummary> routes) async {
    _routes = routes;
  }

  @override
  Future<void> clear() async {
    _routes = null;
  }
}
