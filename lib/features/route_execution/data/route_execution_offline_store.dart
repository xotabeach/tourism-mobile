import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

enum RouteExecutionAction {
  start,
  completeStop,
  uncompleteStop,
  skipStop,
  unskipStop,
  complete,
  cancel,
  pause,
  resume,
}

class RouteExecutionOutboxEntry {
  const RouteExecutionOutboxEntry({
    required this.id,
    required this.executionId,
    required this.action,
    required this.createdAt,
    this.clientEventId,
    this.stopId,
    this.routeId,
    this.attempts = 0,
    this.position,
    this.skipReason,
  });

  final String id;

  /// For [RouteExecutionAction.start] this is the client-generated *local*
  /// execution id (see [RouteExecutionOfflineCoordinator.localExecutionPrefix])
  /// — there is no server id yet. For every other action it is the real
  /// server execution id.
  final String executionId;
  final String? stopId;

  /// Only set for [RouteExecutionAction.start]: the route to start. Every
  /// other action already has its target via [executionId].
  final String? routeId;

  /// Sent to the API so a redelivery is deduped instead of applied twice.
  /// Entries written before this field existed replay without it.
  final String? clientEventId;
  final RouteExecutionAction action;
  final DateTime createdAt;
  final int attempts;

  /// Where the person was when they tapped, for a stop mark made offline.
  /// Lives only until delivery or drop, is never logged, and is not sent if
  /// older than [maxPositionAge].
  final MarkPosition? position;

  /// Only set for [RouteExecutionAction.skipStop].
  final StopSkipReason? skipReason;

  static const maxPositionAge = Duration(hours: 24);

  RouteExecutionOutboxEntry incrementAttempt() => RouteExecutionOutboxEntry(
    id: id,
    executionId: executionId,
    stopId: stopId,
    routeId: routeId,
    clientEventId: clientEventId,
    action: action,
    createdAt: createdAt,
    attempts: attempts + 1,
    position: position,
    skipReason: skipReason,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'execution_id': executionId,
    'stop_id': stopId,
    'route_id': routeId,
    'client_event_id': clientEventId,
    'action': action.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'position': position?.toJson(),
    'skip_reason': skipReason?.apiName,
  };

  /// Throws [FormatException] for an action this build does not know.
  ///
  /// A queue written by a newer build can hold such an entry after a
  /// downgrade. It must never be read as something else: guessing «complete»
  /// would finish the person's route behind their back.
  factory RouteExecutionOutboxEntry.fromJson(Map<String, dynamic> json) {
    final entry = tryFromJson(json);
    if (entry == null) {
      throw FormatException('Unknown outbox action: ${json['action']}');
    }
    return entry;
  }

  /// `null` for an action this build does not know.
  static RouteExecutionOutboxEntry? tryFromJson(Map<String, dynamic> json) {
    final name = json['action'];
    RouteExecutionAction? action;
    for (final item in RouteExecutionAction.values) {
      if (item.name == name) {
        action = item;
        break;
      }
    }
    if (action == null) {
      return null;
    }
    return RouteExecutionOutboxEntry(
      id: json['id'] as String,
      executionId: json['execution_id'] as String,
      stopId: json['stop_id'] as String?,
      routeId: json['route_id'] as String?,
      clientEventId: json['client_event_id'] as String?,
      action: action,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      position: MarkPosition.tryParse(json['position']),
      skipReason: StopSkipReason.tryParse(json['skip_reason']),
    );
  }
}

abstract interface class RouteExecutionOfflineStore {
  Future<RouteExecution?> getSnapshot();

  Future<void> saveSnapshot(RouteExecution execution);

  Future<void> clearSnapshot();

  Future<List<RouteExecutionOutboxEntry>> listOutbox();

  Future<void> enqueue(RouteExecutionOutboxEntry entry);

  Future<void> removeOutbox(String entryId);

  Future<void> clear();
}

final class SharedPreferencesRouteExecutionOfflineStore
    implements RouteExecutionOfflineStore {
  SharedPreferencesRouteExecutionOfflineStore({
    Future<SharedPreferences> Function()? loader,
  }) : _loader = loader ?? SharedPreferences.getInstance;

  static const _snapshotKey = 'crimeatrip.offline.execution.snapshot.v1';
  static const _outboxPrefix = 'crimeatrip.offline.execution.outbox.v1.';

  final Future<SharedPreferences> Function() _loader;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs async => _prefsFuture ??= _loader();

  @override
  Future<RouteExecution?> getSnapshot() async {
    final raw = (await _prefs).getString(_snapshotKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? RouteExecution.fromJson(decoded)
          : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(RouteExecution execution) async {
    await (await _prefs).setString(
      _snapshotKey,
      jsonEncode(execution.toJson()),
    );
  }

  @override
  Future<void> clearSnapshot() async => (await _prefs).remove(_snapshotKey);

  @override
  Future<List<RouteExecutionOutboxEntry>> listOutbox() async {
    final prefs = await _prefs;
    final entries = <RouteExecutionOutboxEntry>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_outboxPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          entries.add(RouteExecutionOutboxEntry.fromJson(decoded));
        }
      } on Object {
        // A corrupt entry, or one whose action this build does not know,
        // must not block other pending actions. It stays under its own key.
      }
    }
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  @override
  Future<void> enqueue(RouteExecutionOutboxEntry entry) async {
    await (await _prefs).setString(
      '$_outboxPrefix${entry.id}',
      jsonEncode(entry.toJson()),
    );
  }

  @override
  Future<void> removeOutbox(String entryId) async {
    await (await _prefs).remove('$_outboxPrefix$entryId');
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_snapshotKey);
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_outboxPrefix),
    )) {
      await prefs.remove(key);
    }
  }
}

final class MemoryRouteExecutionOfflineStore
    implements RouteExecutionOfflineStore {
  RouteExecution? snapshot;
  final entries = <String, RouteExecutionOutboxEntry>{};

  @override
  Future<RouteExecution?> getSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(RouteExecution execution) async {
    snapshot = execution;
  }

  @override
  Future<void> clearSnapshot() async => snapshot = null;

  @override
  Future<List<RouteExecutionOutboxEntry>> listOutbox() async {
    return entries.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> enqueue(RouteExecutionOutboxEntry entry) async {
    entries[entry.id] = entry;
  }

  @override
  Future<void> removeOutbox(String entryId) async => entries.remove(entryId);

  @override
  Future<void> clear() async {
    snapshot = null;
    entries.clear();
  }
}

/// Encrypted account-scoped store used by the real app. The SharedPreferences
/// implementation above remains useful for migration fixtures and local
/// previews, but private execution state must use Keychain/Keystore-backed
/// storage in production.
final class SecureRouteExecutionOfflineStore
    implements RouteExecutionOfflineStore {
  SecureRouteExecutionOfflineStore(this._storage);

  static const _snapshotKey = 'offline.execution.snapshot.v1';
  static const _outboxKey = 'offline.execution.outbox.v1';

  final SecureStoragePort _storage;

  @override
  Future<RouteExecution?> getSnapshot() async {
    final raw = await _storage.read(key: _snapshotKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? RouteExecution.fromJson(decoded)
          : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(RouteExecution execution) {
    return _storage.write(
      key: _snapshotKey,
      value: jsonEncode(execution.toJson()),
    );
  }

  @override
  Future<void> clearSnapshot() => _storage.delete(key: _snapshotKey);

  /// Every stored item as written, including ones this build cannot read:
  /// an action from a newer build survives a rewrite of the list untouched.
  Future<List<Map<String, dynamic>>> _readRaw() async {
    final raw = await _storage.read(key: _outboxKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(growable: true);
    } on Object {
      return [];
    }
  }

  Future<void> _writeRaw(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      await _storage.delete(key: _outboxKey);
      return;
    }
    await _storage.write(key: _outboxKey, value: jsonEncode(items));
  }

  static RouteExecutionOutboxEntry? _parse(Map<String, dynamic> item) {
    try {
      return RouteExecutionOutboxEntry.tryFromJson(item);
    } on Object {
      return null;
    }
  }

  @override
  Future<List<RouteExecutionOutboxEntry>> listOutbox() async {
    final entries = (await _readRaw())
        .map(_parse)
        .nonNulls
        .toList(growable: true);
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  @override
  Future<void> enqueue(RouteExecutionOutboxEntry entry) async {
    final items = await _readRaw();
    final index = items.indexWhere((item) => item['id'] == entry.id);
    if (index == -1) {
      items.add(entry.toJson());
    } else {
      items[index] = entry.toJson();
    }
    await _writeRaw(items);
  }

  @override
  Future<void> removeOutbox(String entryId) async {
    final items = await _readRaw()
      ..removeWhere((item) => item['id'] == entryId);
    await _writeRaw(items);
  }

  @override
  Future<void> clear() async {
    await clearSnapshot();
    await _storage.delete(key: _outboxKey);
  }
}
