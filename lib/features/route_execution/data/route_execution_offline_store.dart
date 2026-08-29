import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

enum RouteExecutionAction { completeStop, complete, cancel }

class RouteExecutionOutboxEntry {
  const RouteExecutionOutboxEntry({
    required this.id,
    required this.executionId,
    required this.action,
    required this.createdAt,
    this.clientEventId,
    this.stopId,
    this.attempts = 0,
  });

  final String id;
  final String executionId;
  final String? stopId;

  /// Sent to the API so a redelivery is deduped instead of applied twice.
  /// Entries written before this field existed replay without it.
  final String? clientEventId;
  final RouteExecutionAction action;
  final DateTime createdAt;
  final int attempts;

  RouteExecutionOutboxEntry incrementAttempt() => RouteExecutionOutboxEntry(
    id: id,
    executionId: executionId,
    stopId: stopId,
    clientEventId: clientEventId,
    action: action,
    createdAt: createdAt,
    attempts: attempts + 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'execution_id': executionId,
    'stop_id': stopId,
    'client_event_id': clientEventId,
    'action': action.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
  };

  factory RouteExecutionOutboxEntry.fromJson(Map<String, dynamic> json) {
    final action = RouteExecutionAction.values.firstWhere(
      (item) => item.name == json['action'],
      orElse: () => RouteExecutionAction.complete,
    );
    return RouteExecutionOutboxEntry(
      id: json['id'] as String,
      executionId: json['execution_id'] as String,
      stopId: json['stop_id'] as String?,
      clientEventId: json['client_event_id'] as String?,
      action: action,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
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
        // A corrupt entry must not block other pending actions.
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

  @override
  Future<List<RouteExecutionOutboxEntry>> listOutbox() async {
    final raw = await _storage.read(key: _outboxKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (item) => RouteExecutionOutboxEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: true);
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return entries;
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> enqueue(RouteExecutionOutboxEntry entry) async {
    final entries = await listOutbox();
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    await _storage.write(
      key: _outboxKey,
      value: jsonEncode(entries.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> removeOutbox(String entryId) async {
    final entries = await listOutbox()
      ..removeWhere((entry) => entry.id == entryId);
    if (entries.isEmpty) {
      await _storage.delete(key: _outboxKey);
      return;
    }
    await _storage.write(
      key: _outboxKey,
      value: jsonEncode(entries.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    await clearSnapshot();
    await _storage.delete(key: _outboxKey);
  }
}
