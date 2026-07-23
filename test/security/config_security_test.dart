import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/config/app_config.dart';

void main() {
  test('non-dev flavors use HTTPS API base URLs', () {
    final staging = AppConfig.fromFlavor(AppFlavor.staging);
    final production = AppConfig.fromFlavor(AppFlavor.production);

    expect(staging.apiBaseUrl.startsWith('https://'), isTrue);
    expect(production.apiBaseUrl.startsWith('https://'), isTrue);
  });

  test('dev flavor may use localhost HTTP for local DX only', () {
    final dev = AppConfig.fromFlavor(AppFlavor.dev);
    expect(dev.flavor, AppFlavor.dev);
    expect(dev.apiBaseUrl.contains('localhost'), isTrue);
  });
}
