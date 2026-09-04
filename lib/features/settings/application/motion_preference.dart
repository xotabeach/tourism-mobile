import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';

/// «Меньше анимаций» — переключатель в настройках.
///
/// Хранится локально и применяется сразу ко всему приложению: длительности
/// в [AppMotion] проходят через один множитель, поэтому включать флаг в
/// каждом виджете не нужно. Значение читается при старте — иначе первый
/// экран успевал бы проиграть анимации, от которых человек отказался.
class MotionPreferenceController extends StateNotifier<bool> {
  MotionPreferenceController() : super(AppMotion.reduceMotion) {
    unawaited(_restore());
  }

  static const _key = 'settings.reduce_motion';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_key);
      if (stored != null) {
        _apply(stored);
      }
    } on Object {
      // Настройка не критична: не прочиталась — остаёмся с анимациями.
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
    AppMotion.reduceMotion = value;
    state = value;
  }
}

final reduceMotionProvider =
    StateNotifierProvider<MotionPreferenceController, bool>((ref) {
      return MotionPreferenceController();
    });
