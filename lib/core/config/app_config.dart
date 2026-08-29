import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { local, test, staging, production }

enum AppDataSource { mock, api }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    required this.dataSource,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appName;
  final AppDataSource dataSource;

  bool get useMockData => dataSource == AppDataSource.mock;

  static AppEnvironment resolveEnvironment({
    required String configuredEnvironment,
    required bool isRelease,
  }) {
    if (configuredEnvironment.isEmpty) {
      return isRelease ? AppEnvironment.production : AppEnvironment.local;
    }
    return switch (configuredEnvironment.toLowerCase()) {
      'local' => AppEnvironment.local,
      'test' => AppEnvironment.test,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      _ => throw StateError('Unsupported APP_ENV: $configuredEnvironment'),
    };
  }

  static AppDataSource _resolveDataSource({
    required String configuredDataSource,
    required AppEnvironment environment,
  }) {
    final source = switch (configuredDataSource.toLowerCase()) {
      '' when environment == AppEnvironment.local => AppDataSource.mock,
      '' => AppDataSource.api,
      'mock' => AppDataSource.mock,
      'api' => AppDataSource.api,
      _ => throw StateError('DATA_SOURCE must be mock or api'),
    };
    if (source == AppDataSource.mock && environment != AppEnvironment.local) {
      throw StateError('Mock data is allowed only in local builds');
    }
    return source;
  }

  static AppConfig fromEnvironment() {
    const configuredEnvironment = String.fromEnvironment('APP_ENV');
    const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const configuredDataSource = String.fromEnvironment('DATA_SOURCE');
    final environment = resolveEnvironment(
      configuredEnvironment: configuredEnvironment,
      isRelease: kReleaseMode,
    );
    return fromValues(
      environment,
      apiBaseUrl: configuredApiBaseUrl.isEmpty ? null : configuredApiBaseUrl,
      dataSource: _resolveDataSource(
        configuredDataSource: configuredDataSource,
        environment: environment,
      ),
    );
  }

  static AppConfig fromValues(
    AppEnvironment environment, {
    String? apiBaseUrl,
    AppDataSource? dataSource,
  }) {
    final resolvedDataSource =
        dataSource ??
        (environment == AppEnvironment.local
            ? AppDataSource.mock
            : AppDataSource.api);
    if (resolvedDataSource == AppDataSource.mock &&
        environment != AppEnvironment.local) {
      throw StateError('Mock data is allowed only in local builds');
    }
    final resolvedApiBaseUrl =
        apiBaseUrl ??
        switch (environment) {
          AppEnvironment.local => 'http://localhost:8000',
          AppEnvironment.test ||
          AppEnvironment.staging ||
          AppEnvironment.production => throw StateError(
            'API_BASE_URL is required for non-local builds',
          ),
        };
    _validateApiBaseUrl(environment, resolvedApiBaseUrl);

    return AppConfig(
      environment: environment,
      apiBaseUrl: resolvedApiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
      appName: switch (environment) {
        AppEnvironment.local => 'КрымТрип (Local)',
        AppEnvironment.test => 'КрымТрип (Test)',
        AppEnvironment.staging => 'КрымТрип (Staging)',
        AppEnvironment.production => 'КрымТрип',
      },
      dataSource: resolvedDataSource,
    );
  }

  static void _validateApiBaseUrl(AppEnvironment environment, String value) {
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
    if (environment != AppEnvironment.local && uri.scheme != 'https') {
      throw StateError('Non-local API_BASE_URL must use HTTPS');
    }
    if (environment != AppEnvironment.local &&
        (uri.host == 'example.com' || uri.host.endsWith('.example.com'))) {
      throw StateError(
        'Non-local API_BASE_URL must not use a placeholder host',
      );
    }
    if (environment == AppEnvironment.local &&
        uri.scheme != 'http' &&
        uri.scheme != 'https') {
      throw StateError('Local API_BASE_URL must use HTTP or HTTPS');
    }
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
