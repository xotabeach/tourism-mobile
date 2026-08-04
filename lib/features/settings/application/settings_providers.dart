import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.autoDownloadFavorites = true,
    this.askBeforeDownload = false,
    this.travelPlusActive = false,
    this.travelPlusYearly = false,
    this.travelPlusExpiresLabel = '29.08.26',
    this.travelPlusDaysLeftLabel = 'Через 26 дней',
    this.paymentLast4 = '1234',
    this.cacheSizeLabel = 'Кеш API мест и маршрутов',
  });

  final bool autoDownloadFavorites;
  final bool askBeforeDownload;
  final bool travelPlusActive;
  final bool travelPlusYearly;
  final String travelPlusExpiresLabel;
  final String travelPlusDaysLeftLabel;
  final String paymentLast4;
  final String cacheSizeLabel;

  SettingsPreferences copyWith({
    bool? autoDownloadFavorites,
    bool? askBeforeDownload,
    bool? travelPlusActive,
    bool? travelPlusYearly,
    String? travelPlusExpiresLabel,
    String? travelPlusDaysLeftLabel,
    String? paymentLast4,
    String? cacheSizeLabel,
  }) {
    return SettingsPreferences(
      autoDownloadFavorites:
          autoDownloadFavorites ?? this.autoDownloadFavorites,
      askBeforeDownload: askBeforeDownload ?? this.askBeforeDownload,
      travelPlusActive: travelPlusActive ?? this.travelPlusActive,
      travelPlusYearly: travelPlusYearly ?? this.travelPlusYearly,
      travelPlusExpiresLabel:
          travelPlusExpiresLabel ?? this.travelPlusExpiresLabel,
      travelPlusDaysLeftLabel:
          travelPlusDaysLeftLabel ?? this.travelPlusDaysLeftLabel,
      paymentLast4: paymentLast4 ?? this.paymentLast4,
      cacheSizeLabel: cacheSizeLabel ?? this.cacheSizeLabel,
    );
  }
}

class SettingsController extends StateNotifier<SettingsPreferences> {
  SettingsController() : super(const SettingsPreferences());

  void setAutoDownload(bool value) =>
      state = state.copyWith(autoDownloadFavorites: value);
  void setAskBeforeDownload(bool value) =>
      state = state.copyWith(askBeforeDownload: value);

  void activateTravelPlus({required bool yearly, String? paymentLast4}) {
    final last4 = _sanitizeLast4(paymentLast4) ?? state.paymentLast4;
    state = state.copyWith(
      travelPlusActive: true,
      travelPlusYearly: yearly,
      travelPlusExpiresLabel: yearly ? '29.07.27' : '29.08.26',
      travelPlusDaysLeftLabel: yearly ? 'Через 365 дней' : 'Через 26 дней',
      paymentLast4: last4,
    );
  }

  void cancelTravelPlus() {
    state = state.copyWith(travelPlusActive: false);
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
