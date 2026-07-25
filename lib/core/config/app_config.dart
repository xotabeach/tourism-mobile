import 'package:flutter/foundation.dart';
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

  static AppFlavor resolveFlavor({
    required String configuredFlavor,
    required bool isRelease,
  }) {
    if (configuredFlavor.isEmpty) {
      return isRelease ? AppFlavor.production : AppFlavor.dev;
    }
    return switch (configuredFlavor.toLowerCase()) {
      'dev' => AppFlavor.dev,
      'staging' => AppFlavor.staging,
      'production' => AppFlavor.production,
      _ => throw StateError('Unsupported APP_FLAVOR: $configuredFlavor'),
    };
  }

  static bool _useMockDataFromEnvironment() {
    const raw = String.fromEnvironment('USE_MOCK_DATA');
    if (raw.isEmpty) {
      return true;
    }
    return switch (raw.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => throw StateError('USE_MOCK_DATA must be true or false'),
    };
  }

  static AppConfig fromEnvironment() {
    const configuredFlavor = String.fromEnvironment('APP_FLAVOR');
    const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final flavor = resolveFlavor(
      configuredFlavor: configuredFlavor,
      isRelease: kReleaseMode,
    );
    return fromFlavor(
      flavor,
      apiBaseUrl: configuredApiBaseUrl.isEmpty ? null : configuredApiBaseUrl,
    );
  }

  static AppConfig fromFlavor(AppFlavor flavor, {String? apiBaseUrl}) {
    final resolvedApiBaseUrl =
        apiBaseUrl ??
        switch (flavor) {
          AppFlavor.dev => 'http://localhost:8000',
          AppFlavor.staging || AppFlavor.production => throw StateError(
            'API_BASE_URL is required for non-dev builds',
          ),
        };
    _validateApiBaseUrl(flavor, resolvedApiBaseUrl);

    return AppConfig(
      flavor: flavor,
      apiBaseUrl: resolvedApiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
      appName: switch (flavor) {
        AppFlavor.dev => 'КрымТрип (Dev)',
        AppFlavor.staging => 'КрымТрип (Staging)',
        AppFlavor.production => 'КрымТрип',
      },
      useMockData: flavor == AppFlavor.dev
          ? _useMockDataFromEnvironment()
          : false,
    );
  }

  static void _validateApiBaseUrl(AppFlavor flavor, String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'API_BASE_URL must be an absolute URL without credentials',
      );
    }
    if (flavor != AppFlavor.dev && uri.scheme != 'https') {
      throw StateError('Non-dev API_BASE_URL must use HTTPS');
    }
    if (flavor != AppFlavor.dev &&
        (uri.host == 'example.com' || uri.host.endsWith('.example.com'))) {
      throw StateError('Non-dev API_BASE_URL must not use a placeholder host');
    }
    if (flavor == AppFlavor.dev &&
        uri.scheme != 'http' &&
        uri.scheme != 'https') {
      throw StateError('Dev API_BASE_URL must use HTTP or HTTPS');
    }
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
