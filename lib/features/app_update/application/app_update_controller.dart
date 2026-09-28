import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/app_update/data/version_policy_repository.dart';
import 'package:tourism_mobile/features/app_update/domain/version_policy.dart';

/// Remembers «Позже» per published version, so a new release asks again.
abstract interface class UpdateSnoozeStore {
  Future<DateTime?> snoozedAt(String version);
  Future<void> snooze(String version, DateTime at);
}

final class PrefsUpdateSnoozeStore implements UpdateSnoozeStore {
  static const _key = 'app_update_snooze';

  @override
  Future<DateTime?> snoozedAt(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    final parts = raw.split('|');
    if (parts.length != 2 || parts.first != version) {
      return null;
    }
    return DateTime.tryParse(parts.last);
  }

  @override
  Future<void> snooze(String version, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, '$version|${at.toUtc().toIso8601String()}');
  }
}

final class MemoryUpdateSnoozeStore implements UpdateSnoozeStore {
  final _values = <String, DateTime>{};

  @override
  Future<DateTime?> snoozedAt(String version) async => _values[version];

  @override
  Future<void> snooze(String version, DateTime at) async {
    _values
      ..clear()
      ..[version] = at;
  }
}

class AppUpdateState {
  const AppUpdateState({
    this.policy = VersionPolicy.none,
    this.showSoft = false,
  });

  final VersionPolicy policy;

  /// The soft prompt is up (not snoozed for this version).
  final bool showSoft;

  bool get blocked => policy.kind == UpdateKind.hard;
}

/// Asks the server whether this build must be updated (BACKEND-5).
///
/// On every start, and on return from the background at most every
/// [recheckAfter] (always while blocked, so an unblock by the admin's kill
/// switch lands quickly). Any failure keeps the last answer or none: a
/// network hiccup never blocks anyone.
class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController({
    required this._repository,
    required this._snoozeStore,
    DateTime Function()? clock,
    bool? supported,
  }) : _clock = clock ?? DateTime.now,
       _supported =
           supported ?? defaultTargetPlatform == TargetPlatform.android,
       super(const AppUpdateState());

  static const recheckAfter = Duration(hours: 6);
  static const snoozeFor = Duration(hours: 24);

  final VersionPolicyRepository _repository;
  final UpdateSnoozeStore _snoozeStore;
  final DateTime Function() _clock;

  /// Only Android has somewhere to update from until there is a store page.
  final bool _supported;
  DateTime? _checkedAt;
  bool _checking = false;

  Future<void> onStart() => _check();

  Future<void> onResumed() async {
    final checkedAt = _checkedAt;
    if (state.blocked ||
        checkedAt == null ||
        _clock().difference(checkedAt) >= recheckAfter) {
      await _check();
    }
  }

  Future<void> later() async {
    final version = state.policy.latestVersion;
    state = AppUpdateState(policy: state.policy);
    if (version != null) {
      await _snoozeStore.snooze(version, _clock());
    }
  }

  Future<void> _check() async {
    if (!_supported || _checking) {
      return;
    }
    _checking = true;
    try {
      final policy = await _repository.fetch();
      _checkedAt = _clock();
      if (!mounted) {
        return;
      }
      state = AppUpdateState(
        policy: policy,
        showSoft: policy.kind == UpdateKind.soft && !await _snoozed(policy),
      );
    } on Object {
      // Offline or a server error: whatever was known stays, nothing new blocks.
    } finally {
      _checking = false;
    }
  }

  Future<bool> _snoozed(VersionPolicy policy) async {
    final version = policy.latestVersion;
    if (version == null) {
      return false;
    }
    final at = await _snoozeStore.snoozedAt(version);
    return at != null && _clock().difference(at) < snoozeFor;
  }
}

final versionPolicyRepositoryProvider = Provider<VersionPolicyRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockData) {
    return const NoUpdateVersionPolicyRepository();
  }
  // No auth: an outdated build may well be signed out, and still must be told.
  return ApiVersionPolicyRepository(ref.watch(rawDioProvider));
});

final updateSnoozeStoreProvider = Provider<UpdateSnoozeStore>(
  (ref) => PrefsUpdateSnoozeStore(),
);

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
      return AppUpdateController(
        repository: ref.watch(versionPolicyRepositoryProvider),
        snoozeStore: ref.watch(updateSnoozeStoreProvider),
      );
    });
