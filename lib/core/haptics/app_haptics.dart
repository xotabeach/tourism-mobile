import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/storage/secure_storage_port.dart';
import 'package:tourism_mobile/core/storage/secure_storage_provider.dart';

/// Device-local haptic gateway. UI code must use this instead of calling
/// [HapticFeedback] directly so the preference applies consistently.
abstract final class AppHaptics {
  static bool _enabled = true;

  static void setEnabled(bool value) => _enabled = value;

  static Future<void> selectionClick() {
    return _enabled ? HapticFeedback.selectionClick() : Future<void>.value();
  }

  static Future<void> mediumImpact() {
    return _enabled ? HapticFeedback.mediumImpact() : Future<void>.value();
  }
}

class AppHapticsController extends StateNotifier<bool> {
  AppHapticsController(this._storage) : super(true) {
    unawaited(_hydrate());
  }

  final SecureStoragePort _storage;
  bool _changedInSession = false;

  Future<void> _hydrate() async {
    final stored = await _storage.read(
      key: SecureStorageKeys.appHapticsEnabled,
    );
    if (_changedInSession) return;
    final enabled = stored != 'false';
    state = enabled;
    AppHaptics.setEnabled(enabled);
  }

  Future<void> setEnabled(bool value) async {
    _changedInSession = true;
    state = value;
    AppHaptics.setEnabled(value);
    await _storage.write(
      key: SecureStorageKeys.appHapticsEnabled,
      value: value.toString(),
    );
  }
}

final appHapticsEnabledProvider =
    StateNotifierProvider<AppHapticsController, bool>((ref) {
      return AppHapticsController(ref.watch(secureStorageProvider));
    });
