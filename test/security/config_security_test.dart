import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/config/app_config.dart';

void main() {
  test('non-local environments use HTTPS API base URLs', () {
    final testConfig = AppConfig.fromValues(
      AppEnvironment.test,
      apiBaseUrl: 'https://test-api.crimeatrip.invalid',
    );
    final staging = AppConfig.fromValues(
      AppEnvironment.staging,
      apiBaseUrl: 'https://staging-api.crimeatrip.invalid',
    );
    final production = AppConfig.fromValues(
      AppEnvironment.production,
      apiBaseUrl: 'https://api.crimeatrip.invalid',
    );

    expect(testConfig.apiBaseUrl.startsWith('https://'), isTrue);
    expect(staging.apiBaseUrl.startsWith('https://'), isTrue);
    expect(production.apiBaseUrl.startsWith('https://'), isTrue);
  });

  test('local defaults to localhost mock data', () {
    final local = AppConfig.fromValues(AppEnvironment.local);
    expect(local.environment, AppEnvironment.local);
    expect(local.apiBaseUrl.contains('localhost'), isTrue);
    expect(local.dataSource, AppDataSource.mock);
  });

  test('test staging and production default to API data', () {
    for (final environment in [
      AppEnvironment.test,
      AppEnvironment.staging,
      AppEnvironment.production,
    ]) {
      expect(
        AppConfig.fromValues(
          environment,
          apiBaseUrl: 'https://api.crimeatrip.invalid',
        ).dataSource,
        AppDataSource.api,
      );
    }
  });

  test(
    'release defaults to production while non-release defaults to local',
    () {
      expect(
        AppConfig.resolveEnvironment(
          configuredEnvironment: '',
          isRelease: true,
        ),
        AppEnvironment.production,
      );
      expect(
        AppConfig.resolveEnvironment(
          configuredEnvironment: '',
          isRelease: false,
        ),
        AppEnvironment.local,
      );
    },
  );

  test('non-local environment requires a non-placeholder HTTPS API URL', () {
    expect(() => AppConfig.fromValues(AppEnvironment.test), throwsStateError);
    expect(
      () => AppConfig.fromValues(
        AppEnvironment.test,
        apiBaseUrl: 'http://api.crimeatrip.invalid',
      ),
      throwsStateError,
    );
    expect(
      () => AppConfig.fromValues(
        AppEnvironment.production,
        apiBaseUrl: 'https://api.example.com',
      ),
      throwsStateError,
    );
  });

  test('mock data is rejected outside local', () {
    expect(
      () => AppConfig.fromValues(
        AppEnvironment.test,
        apiBaseUrl: 'https://test-api.crimeatrip.invalid',
        dataSource: AppDataSource.mock,
      ),
      throwsStateError,
    );
  });

  test('unknown environment is rejected', () {
    expect(
      () => AppConfig.resolveEnvironment(
        configuredEnvironment: 'gamma',
        isRelease: false,
      ),
      throwsStateError,
    );
  });
}
