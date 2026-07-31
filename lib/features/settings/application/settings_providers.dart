import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.autoDownloadFavorites = true,
    this.askBeforeDownload = false,
    this.travelPlusActive = false,
    this.travelPlusExpiresLabel = '29.08.26',
    this.cacheSizeLabel = 'Кеш API мест и маршрутов',
  });

  final bool autoDownloadFavorites;
  final bool askBeforeDownload;
  final bool travelPlusActive;
  final String travelPlusExpiresLabel;
  final String cacheSizeLabel;

  SettingsPreferences copyWith({
    bool? autoDownloadFavorites,
    bool? askBeforeDownload,
    bool? travelPlusActive,
    String? travelPlusExpiresLabel,
    String? cacheSizeLabel,
  }) {
    return SettingsPreferences(
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
