import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.pushEnabled = true,
    this.smsEnabled = false,
    this.hapticsEnabled = true,
    this.autoDownloadFavorites = true,
    this.askBeforeDownload = false,
    this.travelPlusActive = false,
    this.travelPlusExpiresLabel = '29.08.26',
    this.cacheSizeLabel = 'Кеш API мест и маршрутов',
  });

  final bool pushEnabled;
  final bool smsEnabled;
  final bool hapticsEnabled;
  final bool autoDownloadFavorites;
  final bool askBeforeDownload;
  final bool travelPlusActive;
  final String travelPlusExpiresLabel;
  final String cacheSizeLabel;

  SettingsPreferences copyWith({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? hapticsEnabled,
    bool? autoDownloadFavorites,
    bool? askBeforeDownload,
    bool? travelPlusActive,
    String? travelPlusExpiresLabel,
    String? cacheSizeLabel,
  }) {
    return SettingsPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      autoDownloadFavorites:
          autoDownloadFavorites ?? this.autoDownloadFavorites,
      askBeforeDownload: askBeforeDownload ?? this.askBeforeDownload,
      travelPlusActive: travelPlusActive ?? this.travelPlusActive,
      travelPlusExpiresLabel:
          travelPlusExpiresLabel ?? this.travelPlusExpiresLabel,
      cacheSizeLabel: cacheSizeLabel ?? this.cacheSizeLabel,
    );
  }
}

class SettingsController extends StateNotifier<SettingsPreferences> {
  SettingsController() : super(const SettingsPreferences());

  void setPush(bool value) => state = state.copyWith(pushEnabled: value);
  void setSms(bool value) => state = state.copyWith(smsEnabled: value);
  void setHaptics(bool value) => state = state.copyWith(hapticsEnabled: value);
  void setAutoDownload(bool value) =>
      state = state.copyWith(autoDownloadFavorites: value);
  void setAskBeforeDownload(bool value) =>
      state = state.copyWith(askBeforeDownload: value);

  void activateTravelPlus({required bool yearly}) {
    state = state.copyWith(
      travelPlusActive: true,
      travelPlusExpiresLabel: yearly ? '29.07.27' : '29.08.26',
    );
  }

  void clearCacheLabel() {
    state = state.copyWith(cacheSizeLabel: 'Кеш API очищен');
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsController, SettingsPreferences>((ref) {
      return SettingsController();
    });
