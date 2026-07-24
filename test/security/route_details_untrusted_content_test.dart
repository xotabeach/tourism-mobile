import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/domain/routes_repository.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';

const _config = AppConfig(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'http://localhost:8000',
  appName: 'КрымТрип (Security)',
  useMockData: true,
);

const _xss = '<script>alert("xss")</script>';
final _oversizedDescription = 'ЖЖЖ ' * 4000;

class _HostileRoutesRepository implements RoutesRepository {
  @override
  Future<RouteListPage> listRoutes({String? regionSlug}) async {
    return const RouteListPage(items: [], total: 0, limit: 20, offset: 0);
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    return RouteDetail(
      id: id,
      name: 'Маршрут $_xss',
      slug: 'hostile-route',
      shortDescription: _xss,
      description: '$_xss $_oversizedDescription',
      stopsCount: 2,
      estimatedDurationMinutes: 90,
      distanceMeters: 4200,
      difficulty: 'easy',
      transportMode: 'walk',
      authorLabel: 'javascript:alert(1)',
      coverImageUrl: 'javascript:alert(1)',
      stops: [
        const RouteStop(
          id: 'stop-1',
          position: 1,
          placeId: '../../etc/passwd',
          placeName: "Место'; DROP TABLE places; --",
          placeSlug: 'hostile-place',
          visitDurationMinutes: 30,
          note: _xss,
        ),
        const RouteStop(
          id: 'stop-2',
          position: 2,
          placeId: 'mock-livadia-palace',
          placeName: 'Обычное место',
          placeSlug: 'livadia-palace',
          visitDurationMinutes: 30,
        ),
      ],
    );
  }
}

Future<void> _pumpDetails(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        routesRepositoryProvider.overrideWithValue(_HostileRoutesRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const RouteDetailsScreen(routeId: 'hostile-route'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('route details renders server text as inert data', (
    tester,
  ) async {
    await _pumpDetails(tester);

    // Script-like and SQL-like payloads stay literal text, never markup.
    expect(find.textContaining(_xss), findsWidgets);
    expect(find.textContaining('DROP TABLE places'), findsOneWidget);

    final title = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((text) => (text.data ?? '').startsWith('Маршрут <script>'));
    expect(title.data, 'Маршрут $_xss');
  });

  test('media URLs from the server accept http(s) and plain paths only', () {
    expect(AppImages.resolveMediaUrl(_config, 'javascript:alert(1)'), isNull);
    expect(
      AppImages.resolveMediaUrl(_config, 'data:image/png;base64,AA'),
      isNull,
    );
    expect(AppImages.resolveMediaUrl(_config, 'file:///etc/passwd'), isNull);
    expect(
      AppImages.resolveMediaUrl(_config, 'media/cover.jpg'),
      'http://localhost:8000/media/cover.jpg',
    );
    expect(
      AppImages.resolveMediaUrl(_config, 'https://cdn.example/cover.jpg'),
      'https://cdn.example/cover.jpg',
    );
  });

  testWidgets('oversized untrusted text stays bounded and does not overflow', (
    tester,
  ) async {
    await _pumpDetails(tester);

    final description = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((text) => (text.data ?? '').contains('ЖЖЖ'));
    expect(description.maxLines, 3);
    expect(description.overflow, TextOverflow.ellipsis);

    expect(tester.takeException(), isNull);
  });

  testWidgets('stop rows keep untrusted place ids out of rendered text', (
    tester,
  ) async {
    await _pumpDetails(tester);

    expect(find.textContaining('../../etc/passwd'), findsNothing);
  });
}
