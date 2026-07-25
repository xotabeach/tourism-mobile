import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/config/app_config.dart';

void main() {
  test('non-dev flavors use HTTPS API base URLs', () {
    final staging = AppConfig.fromFlavor(
      AppFlavor.staging,
      apiBaseUrl: 'https://staging-api.crimeatrip.test',
    );
    final production = AppConfig.fromFlavor(
      AppFlavor.production,
      apiBaseUrl: 'https://api.crimeatrip.test',
    );

    expect(staging.apiBaseUrl.startsWith('https://'), isTrue);
    expect(production.apiBaseUrl.startsWith('https://'), isTrue);
  });

  test('dev flavor may use localhost HTTP for local DX only', () {
    final dev = AppConfig.fromFlavor(AppFlavor.dev);
    expect(dev.flavor, AppFlavor.dev);
    expect(dev.apiBaseUrl.contains('localhost'), isTrue);
    expect(dev.useMockData, isTrue);
  });

  test('staging and production keep mock data off by default', () {
    expect(
      AppConfig.fromFlavor(
        AppFlavor.staging,
        apiBaseUrl: 'https://staging-api.crimeatrip.test',
      ).useMockData,
      isFalse,
    );
    expect(
      AppConfig.fromFlavor(
        AppFlavor.production,
        apiBaseUrl: 'https://api.crimeatrip.test',
      ).useMockData,
      isFalse,
    );
  });

  test('release defaults to production while non-release defaults to dev', () {
    expect(
      AppConfig.resolveFlavor(configuredFlavor: '', isRelease: true),
      AppFlavor.production,
    );
    expect(
      AppConfig.resolveFlavor(configuredFlavor: '', isRelease: false),
      AppFlavor.dev,
    );
  });

  test('non-dev flavor requires a non-placeholder HTTPS API URL', () {
    expect(() => AppConfig.fromFlavor(AppFlavor.production), throwsStateError);
    expect(
      () => AppConfig.fromFlavor(
        AppFlavor.production,
        apiBaseUrl: 'http://api.crimeatrip.test',
      ),
      throwsStateError,
    );
    expect(
      () => AppConfig.fromFlavor(
        AppFlavor.production,
        apiBaseUrl: 'https://api.example.com',
      ),
      throwsStateError,
    );
  });
}
