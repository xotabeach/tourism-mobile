import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// «Жидкое стекло» — переключатель в настройках (iOS only; Android всегда
/// показывает обычные кнопки, см. [AppAdaptivePrimaryButton]).
///
/// Тот же паттерн, что и [MotionPreferenceController]: значение хранится
/// локально и применяется через статическое поле ([AppGlassSettings.enabled]),
/// а не через watch в каждом виджете — кнопки читают его напрямую в build().
class LiquidGlassPreferenceController extends StateNotifier<bool> {
  LiquidGlassPreferenceController() : super(AppGlassSettings.enabled) {
    unawaited(_restore());
  }

  static const _key = 'settings.liquid_glass_enabled';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_key);
      if (stored != null) {
        _apply(stored);
      }
    } on Object {
      // Настройка не критична: не прочиталась — остаёмся со стеклом по умолчанию.
    }
  }

  Future<void> set(bool value) async {
    _apply(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } on Object {
      // Не сохранилось — в этой сессии всё равно применено.
    }
  }

  void _apply(bool value) {
    AppGlassSettings.enabled = value;
    state = value;
  }
}

final liquidGlassEnabledProvider =
    StateNotifierProvider<LiquidGlassPreferenceController, bool>((ref) {
      return LiquidGlassPreferenceController();
    });
