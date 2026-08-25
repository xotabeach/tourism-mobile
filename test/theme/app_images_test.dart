import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';

void main() {
  const config = AppConfig(
    environment: AppEnvironment.local,
    apiBaseUrl: 'https://example.test',
    appName: 'Test',
    dataSource: AppDataSource.mock,
  );

  testWidgets(
    'coverImage decodes width-only, so BoxFit.cover crops instead of '
    'squishing a wide photo inside a tall card',
    (tester) async {
      // Regression: passing both memCacheWidth and memCacheHeight makes the
      // engine decode to that exact pixel box, non-uniformly stretching a
      // source whose aspect ratio does not match the card (the swipe-deck
      // cards are tall, most place/route photos are wide) — BoxFit.cover
      // then just crops an already-distorted raster instead of the source.
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 320,
            child: AppImages.coverImage(
              config: config,
              coverImageUrl: '/media/wide-photo.jpg',
              fallbackSeed: 'seed',
            ),
          ),
        ),
      );
      await tester.pump();

      final widget = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(widget.memCacheHeight, isNull);
      expect(widget.memCacheWidth, isNotNull);
      expect(widget.fit, BoxFit.cover);
    },
  );
}
