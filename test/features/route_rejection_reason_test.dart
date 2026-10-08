import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';

import '../support/test_overrides.dart';

// BACKEND-34: a route returned by a moderator tells its author what to fix.

const _reason =
    'Нужны другие фотографии: обложка и фото точек должны показывать сам '
    'маршрут. Нет фото финиша';

RouteDetail _detail({required String status, String? reason}) => RouteDetail(
  id: 'returned-route',
  name: 'Возвращённый маршрут',
  slug: 'returned-route',
  shortDescription: 'Описание',
  description: 'Полное описание маршрута',
  stopsCount: 0,
  ownerUserId: 'mock-user',
  visibility: 'private',
  publicationStatus: status,
  rejectionReason: reason,
  source: 'user_created',
  media: const [],
  stops: const [],
);

Future<void> _pump(WidgetTester tester, RouteDetail detail) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        ownRouteDetailProvider.overrideWith((ref, id) async => detail),
      ],
      child: MaterialApp(
        home: RouteDetailsScreen(routeId: detail.id, initialRoute: detail),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the reason is read from the API and kept in the offline copy', () {
    final route = RouteSummary.fromJson({
      'id': 'r1',
      'name': 'Тропа',
      'slug': 'tropa',
      'short_description': null,
      'stops_count': 2,
      'publication_status': 'rejected',
      'rejection_reason': _reason,
    });

    expect(route.rejectionReason, _reason);
    expect(RouteSummary.fromJson(route.toJson()).rejectionReason, _reason);
    expect(
      RouteSummary.fromJson({
        'id': 'r2',
        'name': 'Тропа',
        'slug': 'tropa-2',
        'short_description': null,
        'stops_count': 2,
      }).rejectionReason,
      isNull,
    );
  });

  testWidgets('a returned route shows what to fix', (tester) async {
    await _pump(tester, _detail(status: 'rejected', reason: _reason));

    expect(find.byKey(const ValueKey('route-owner-status')), findsOneWidget);
    expect(find.text('Что исправить: $_reason'), findsOneWidget);
    expect(
      find.text('Перед публикацией маршруту нужны исправления.'),
      findsNothing,
    );
  });

  testWidgets('a rejection without a reason keeps the general wording', (
    tester,
  ) async {
    await _pump(tester, _detail(status: 'rejected'));

    expect(
      find.text('Перед публикацией маршруту нужны исправления.'),
      findsOneWidget,
    );
    expect(find.textContaining('Что исправить'), findsNothing);
  });

  testWidgets('a route waiting for review never shows an old reason', (
    tester,
  ) async {
    await _pump(tester, _detail(status: 'pending_review', reason: _reason));

    expect(find.textContaining('Что исправить'), findsNothing);
  });
}
