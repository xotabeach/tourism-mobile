import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';

void main() {
  const config = AppConfig(
    environment: AppEnvironment.local,
    apiBaseUrl: 'http://127.0.0.1:8000',
    appName: 'CrimeaTrip',
    dataSource: AppDataSource.api,
  );

  test('resolveMediaUrl rejects javascript and data schemes', () {
    expect(AppImages.resolveMediaUrl(config, 'javascript:alert(1)'), isNull);
    expect(AppImages.resolveMediaUrl(config, 'data:text/html,hi'), isNull);
    expect(AppImages.resolveMediaUrl(config, 'file:///tmp/x'), isNull);
  });

  test('imageProvider accepts trusted http(s) without throwing', () {
    final provider = AppImages.imageProvider(
      resolvedUrl: 'http://127.0.0.1:8000/media/profiles/a.webp',
    );
    expect(provider, isNotNull);
  });
}
