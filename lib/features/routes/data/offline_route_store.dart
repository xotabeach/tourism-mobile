import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/routes/domain/route.dart';

/// A complete route snapshot that can be rendered without a network request.
/// Images are kept in the app image cache; the JSON snapshot is the source of
/// truth for the route screen itself.
class OfflineRouteRecord {
  const OfflineRouteRecord({required this.route, required this.downloadedAt});

  final RouteDetail route;
  final DateTime downloadedAt;

  String get id => route.id;
}

abstract interface class OfflineRouteStore {
  Future<List<OfflineRouteRecord>> list();

  Future<OfflineRouteRecord?> get(String routeId);

  Future<void> save(RouteDetail route);

  Future<void> remove(String routeId);

  Future<void> clear();
}

/// Small, versioned JSON store. SharedPreferences is intentionally used only
/// for route snapshots (never tokens); secure auth storage remains separate.
final class SharedPreferencesOfflineRouteStore implements OfflineRouteStore {
  SharedPreferencesOfflineRouteStore({
    Future<SharedPreferences> Function()? loader,
  }) : _loader = loader ?? SharedPreferences.getInstance;

  static const _prefix = 'crimeatrip.offline.route.';
  static const _version = 1;

  final Future<SharedPreferences> Function() _loader;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs async => _prefsFuture ??= _loader();

  @override
  Future<List<OfflineRouteRecord>> list() async {
    final prefs = await _prefs;
    final records = <OfflineRouteRecord>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) {
        continue;
      }
      final raw = prefs.getString(key);
      if (raw == null) {
        continue;
      }
      final record = _decode(raw);
      if (record != null) {
        records.add(record);
      }
    }
    records.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return records;
  }

  @override
  Future<OfflineRouteRecord?> get(String routeId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(routeId));
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> save(RouteDetail route) async {
    final prefs = await _prefs;
    final payload = <String, dynamic>{
      'version': _version,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
      'route': route.toJson(),
    };
    await prefs.setString(_key(route.id), jsonEncode(payload));
  }

  @override
  Future<void> remove(String routeId) async {
    final prefs = await _prefs;
    await prefs.remove(_key(routeId));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  String _key(String routeId) => '$_prefix$routeId';

  OfflineRouteRecord? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != _version) {
        return null;
      }
      final timestamp = DateTime.tryParse(
        decoded['downloaded_at'] as String? ?? '',
      );
      final routeJson = decoded['route'];
      if (timestamp == null || routeJson is! Map<String, dynamic>) {
        return null;
      }
      return OfflineRouteRecord(
        route: RouteDetail.fromJson(routeJson),
        downloadedAt: timestamp.toLocal(),
      );
    } on Object {
      // A corrupt/stale local entry must not make the offline screen fail.
      return null;
    }
  }
}

/// Deterministic implementation for widget/unit tests and local previews.
final class MemoryOfflineRouteStore implements OfflineRouteStore {
  final _routes = <String, OfflineRouteRecord>{};

  @override
  Future<List<OfflineRouteRecord>> list() async {
    final records = _routes.values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return records;
  }

  @override
  Future<OfflineRouteRecord?> get(String routeId) async => _routes[routeId];

  @override
  Future<void> save(RouteDetail route) async {
    _routes[route.id] = OfflineRouteRecord(
      route: route,
      downloadedAt: DateTime.now(),
    );
  }

  @override
  Future<void> remove(String routeId) async {
    _routes.remove(routeId);
  }

  @override
  Future<void> clear() async {
    _routes.clear();
  }
}
