import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppFlavor { dev, staging, production }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.appName,
    required this.useMockData,
  });

  final AppFlavor flavor;
  final String apiBaseUrl;
  final String appName;
  final bool useMockData;

  /// Dev defaults to mock so Flutter runs without Docker/backend.
  /// Override: `--dart-define=USE_MOCK_DATA=false` (or `true`).
  static bool _useMockDataFromEnvironment({required bool defaultValue}) {
    const raw = String.fromEnvironment('USE_MOCK_DATA');
    if (raw.isEmpty) {
      return defaultValue;
    }
    return raw.toLowerCase() == 'true';
  }

  static AppConfig fromFlavor(AppFlavor flavor) {
    return switch (flavor) {
      AppFlavor.dev => AppConfig(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://localhost:8000',
        appName: 'КрымТрип (Dev)',
        useMockData: _useMockDataFromEnvironment(defaultValue: true),
      ),
      AppFlavor.staging => AppConfig(
        flavor: AppFlavor.staging,
        apiBaseUrl: 'https://staging-api.example.com',
        appName: 'КрымТрип (Staging)',
        useMockData: _useMockDataFromEnvironment(defaultValue: false),
      ),
      AppFlavor.production => AppConfig(
        flavor: AppFlavor.production,
        apiBaseUrl: 'https://api.example.com',
        appName: 'КрымТрип',
        useMockData: _useMockDataFromEnvironment(defaultValue: false),
      ),
    };
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromFlavor(AppFlavor.dev),
);
