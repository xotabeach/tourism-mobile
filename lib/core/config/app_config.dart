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

  static AppConfig fromFlavor(AppFlavor flavor) {
    return switch (flavor) {
      AppFlavor.dev => const AppConfig(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://localhost:8000',
        appName: 'Crimea Travel (Dev)',
        useMockData: true,
      ),
      AppFlavor.staging => const AppConfig(
        flavor: AppFlavor.staging,
        apiBaseUrl: 'https://staging-api.example.com',
        appName: 'Crimea Travel (Staging)',
        useMockData: false,
      ),
      AppFlavor.production => const AppConfig(
        flavor: AppFlavor.production,
        apiBaseUrl: 'https://api.example.com',
        appName: 'Crimea Travel',
        useMockData: false,
      ),
    };
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromFlavor(AppFlavor.dev),
);
