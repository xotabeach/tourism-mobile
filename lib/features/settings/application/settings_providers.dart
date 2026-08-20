import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.autoDownloadFavorites = true,
    this.askBeforeDownload = false,
    this.paymentLast4 = '1234',
    this.cacheSizeLabel = 'Кеш API мест и маршрутов',
  });

  final bool autoDownloadFavorites;
  final bool askBeforeDownload;
  final String paymentLast4;
  final String cacheSizeLabel;

  SettingsPreferences copyWith({
    bool? autoDownloadFavorites,
    bool? askBeforeDownload,
    String? paymentLast4,
    String? cacheSizeLabel,
  }) {
    return SettingsPreferences(
      autoDownloadFavorites:
          autoDownloadFavorites ?? this.autoDownloadFavorites,
      askBeforeDownload: askBeforeDownload ?? this.askBeforeDownload,
      paymentLast4: paymentLast4 ?? this.paymentLast4,
      cacheSizeLabel: cacheSizeLabel ?? this.cacheSizeLabel,
    );
  }
}

/// Travel+ status comes from the authenticated session / backend, not local
/// prefs. Payment card last4 remains local mock until store billing lands.
class TravelPlusViewState {
  const TravelPlusViewState({
    required this.active,
    required this.yearly,
    required this.expiresLabel,
    required this.daysLeftLabel,
    required this.paymentLast4,
  });

  final bool active;
  final bool yearly;
  final String expiresLabel;
  final String daysLeftLabel;
  final String paymentLast4;
}

String formatTravelPlusExpiresLabel(DateTime? expiresAt) {
  if (expiresAt == null) {
    return '—';
  }
  final d = expiresAt.day.toString().padLeft(2, '0');
  final m = expiresAt.month.toString().padLeft(2, '0');
  final y = (expiresAt.year % 100).toString().padLeft(2, '0');
  return '$d.$m.$y';
}

String formatTravelPlusDaysLeftLabel(DateTime? expiresAt) {
  if (expiresAt == null) {
    return 'Подписка не активна';
  }
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days <= 0) {
    return 'Истекает сегодня';
  }
  return 'Через $days ${_daysWord(days)}';
}

String _daysWord(int days) {
  final mod100 = days % 100;
  final mod10 = days % 10;
  if (mod100 >= 11 && mod100 <= 14) {
    return 'дней';
  }
  if (mod10 == 1) {
    return 'день';
  }
  if (mod10 >= 2 && mod10 <= 4) {
    return 'дня';
  }
  return 'дней';
}

class SettingsController extends StateNotifier<SettingsPreferences> {
  SettingsController() : super(const SettingsPreferences());

  void setAutoDownload(bool value) =>
      state = state.copyWith(autoDownloadFavorites: value);
  void setAskBeforeDownload(bool value) =>
      state = state.copyWith(askBeforeDownload: value);

  void setPaymentLast4(String? paymentLast4) {
    final last4 = _sanitizeLast4(paymentLast4);
    if (last4 == null) {
      return;
    }
    state = state.copyWith(paymentLast4: last4);
  }

  void clearCacheLabel() {
    state = state.copyWith(cacheSizeLabel: 'Кеш API очищен');
  }

  static String? _sanitizeLast4(String? raw) {
    if (raw == null) {
      return null;
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return null;
    }
    return digits.substring(digits.length - 4);
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsController, SettingsPreferences>((ref) {
      return SettingsController();
    });

final travelPlusViewProvider = Provider<TravelPlusViewState>((ref) {
  final session = ref.watch(sessionProvider);
  final prefs = ref.watch(settingsPreferencesProvider);
  return TravelPlusViewState(
    active: session.travelPlusActive,
    yearly: session.travelPlusPlan == 'yearly',
    expiresLabel: formatTravelPlusExpiresLabel(session.travelPlusExpiresAt),
    daysLeftLabel: formatTravelPlusDaysLeftLabel(session.travelPlusExpiresAt),
    paymentLast4: prefs.paymentLast4,
  );
});
