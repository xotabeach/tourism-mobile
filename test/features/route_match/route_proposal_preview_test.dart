import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/data/route_match_repository.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/domain/route_proposal_preview.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_proposal_preview_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

import '../../support/test_overrides.dart';

class _PreviewRepository extends MockRouteMatchRepository {
  int accepted = 0;
  int dateUpdates = 0;
  bool failNextPreview = false;

  @override
  Future<RouteProposalPreview> previewProposal(String id) async {
    if (failNextPreview) {
      failNextPreview = false;
      throw const NetworkFailure('Не удалось загрузить маршрут');
    }
    return super.previewProposal(id);
  }

  @override
  Future<RouteProposalPreview> updateProposalDate(String id, DateTime date) {
    dateUpdates++;
    return super.updateProposalDate(id, date);
  }

  @override
  Future<RouteProposalResult> acceptProposal(String id) {
    accepted++;
    return super.acceptProposal(id);
  }
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, _PreviewRepository repository) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testSessionOverrides(onboardingCompleted: true),
            routeMatchRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: RouteProposalPreviewScreen(proposalId: 'preview'),
          ),
        ),
      );

  testWidgets('map uses proposal stops without accepting or saving a route', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    await pumpScreen(tester, repository);
    await tester.pumpAndSettle();
    final map = tester.widget<RouteStaticMap>(find.byType(RouteStaticMap));
    expect(map.stops.map((s) => s.placeId), ['1', '2']);
    expect(map.stops.first.lat, 44.492);
    expect(map.imageHeaders, {'Authorization': 'Bearer mock-access'});
    expect(
      find.textContaining('Дорожный путь пока не подтверждён'),
      findsOneWidget,
    );
    expect(repository.accepted, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day plan saves a calendar date without accepting the proposal', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    await pumpScreen(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('По дням'));
    await tester.pumpAndSettle();
    expect(find.text('День 1'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Набережная Ялты'), findsOneWidget);
    await tester.tap(find.text('Выбрать дату начала'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repository.dateUpdates, 1);
    expect(repository.accepted, 0);
    expect(find.textContaining('Начало:'), findsOneWidget);
    expect(find.textContaining('День 1 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview load errors are retryable', (tester) async {
    final repository = _PreviewRepository()..failNextPreview = true;
    await pumpScreen(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить маршрут'), findsOneWidget);
    await tester.tap(find.text('Попробовать ещё раз'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteStaticMap), findsOneWidget);
    expect(repository.accepted, 0);
  });

  testWidgets('pending preview keeps the app loading skeleton', (tester) async {
    final pending = Completer<RouteProposalPreview>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSessionOverrides(onboardingCompleted: true),
          proposalPreviewProvider(
            'preview',
          ).overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          home: RouteProposalPreviewScreen(proposalId: 'preview'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppListSkeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
