import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/core/design/components/audio_guide_card.dart';
import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/data/place_reviews_repository.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/places/presentation/place_details_screen.dart';
import 'package:tourism_mobile/features/reviews/presentation/entity_reviews_section.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

import '../support/test_overrides.dart';

RouteReview _review({
  required String id,
  required String entityId,
  required String body,
}) {
  return RouteReview(
    id: id,
    routeId: entityId,
    authorUserId: 'u1',
    authorDisplayName: 'Автор',
    authorRankTitle: 'Новичок',
    body: body,
    rating: 5,
    status: 'published',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

class _FakePlaceReviews implements PlaceReviewsRepository {
  @override
  Future<RouteReviewsPage> listPublished(String placeId) async {
    return RouteReviewsPage(
      items: [_review(id: 'p1', entityId: placeId, body: 'PLACE_ONLY_REVIEW')],
      total: 1,
      ratingCount: 1,
      averageRating: 5,
    );
  }

  @override
  Future<RouteReview> submit({
    required String placeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String placeId, required String reviewId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<RouteReview>> listMine() async => const [];
}

class _FakeRouteReviews implements RouteReviewsRepository {
  @override
  Future<RouteReviewsPage> listPublished(String routeId) async {
    return RouteReviewsPage(
      items: [_review(id: 'r1', entityId: routeId, body: 'ROUTE_ONLY_REVIEW')],
      total: 1,
      ratingCount: 1,
      averageRating: 4,
    );
  }

  @override
  Future<RouteReview> submit({
    required String routeId,
    required String body,
    required int rating,
    List<String> imagePaths = const [],
    String? replyToReviewId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String routeId, required String reviewId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMedia({
    required String routeId,
    required String reviewId,
    required String mediaId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<RouteReview>> listMine() async => const [];
}

Widget _sectionApp({
  required ReviewEntityKind kind,
  bool allowComposer = true,
}) {
  return ProviderScope(
    overrides: [
      ...testSessionOverrides(onboardingCompleted: true),
      placeReviewsRepositoryProvider.overrideWithValue(_FakePlaceReviews()),
      routeReviewsRepositoryProvider.overrideWithValue(_FakeRouteReviews()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EntityReviewsSection(
            entityId: 'entity-1',
            kind: kind,
            allowComposer: allowComposer,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('HeroCollapseSpec keeps place and route fade/scale contracts', () {
    expect(HeroCollapseSpec.place.scale, isFalse);
    expect(HeroCollapseSpec.place.fadeOutStart, 0.02);
    expect(HeroCollapseSpec.place.fadeOutEnd, 0.64);
    expect(HeroCollapseSpec.place.fadeInStart, 0.55);
    expect(HeroCollapseSpec.place.fadeInEnd, 0.92);
    expect(HeroCollapseSpec.route.scale, isTrue);
    expect(HeroCollapseSpec.route.fadeOutStart, 0);
    expect(HeroCollapseSpec.route.fadeOutEnd, 0.55);
    expect(HeroCollapseSpec.route.fadeInStart, 0.4);
    expect(HeroCollapseSpec.route.fadeInEnd, 0.9);
  });

  test('AudioGuideCard source has no raw hex colors', () {
    final src = File(
      'lib/core/design/components/audio_guide_card.dart',
    ).readAsStringSync();
    expect(src.contains('Color(0x'), isFalse);
    expect(src.contains('AppColors.hairline'), isTrue);
  });

  testWidgets('AudioGuideCard paints with AppColors tokens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioGuideCard(
            title: 'Ялта',
            image: MemoryImage(
              Uint8List.fromList(const [
                0x89,
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A,
                0x00,
                0x00,
                0x00,
                0x0D,
                0x49,
                0x48,
                0x44,
                0x52,
                0x00,
                0x00,
                0x00,
                0x01,
                0x00,
                0x00,
                0x00,
                0x01,
                0x08,
                0x06,
                0x00,
                0x00,
                0x00,
                0x1F,
                0x15,
                0xC4,
                0x89,
                0x00,
                0x00,
                0x00,
                0x0A,
                0x49,
                0x44,
                0x41,
                0x54,
                0x78,
                0x9C,
                0x63,
                0x00,
                0x01,
                0x00,
                0x00,
                0x05,
                0x00,
                0x01,
                0x0D,
                0x0A,
                0x2D,
                0xB4,
                0x00,
                0x00,
                0x00,
                0x00,
                0x49,
                0x45,
                0x4E,
                0x44,
                0xAE,
                0x42,
                0x60,
                0x82,
              ]),
            ),
            onPlay: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('КрымТрип'), findsOneWidget);
    final card = tester.widget<Container>(find.byType(Container).first);
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.elevatedSurface);
    expect(decoration.border?.top.color, AppColors.hairline);
  });

  testWidgets('EntityReviewsSection place fake repo does not show route copy', (
    tester,
  ) async {
    await tester.pumpWidget(_sectionApp(kind: ReviewEntityKind.place));
    await tester.pumpAndSettle();
    expect(find.text('PLACE_ONLY_REVIEW'), findsOneWidget);
    expect(find.text('ROUTE_ONLY_REVIEW'), findsNothing);
  });

  testWidgets('EntityReviewsSection route fake repo does not show place copy', (
    tester,
  ) async {
    await tester.pumpWidget(_sectionApp(kind: ReviewEntityKind.route));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE_ONLY_REVIEW'), findsOneWidget);
    expect(find.text('PLACE_ONLY_REVIEW'), findsNothing);
  });

  testWidgets('unpublished route reviews show the composer lock hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sectionApp(kind: ReviewEntityKind.route, allowComposer: false),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reviews-unpublished-hint')),
      findsOneWidget,
    );
    expect(find.text('ROUTE_ONLY_REVIEW'), findsNothing);
  });

  testWidgets('place details loading keeps back and shimmer chrome', (
    tester,
  ) async {
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
          ...testSessionOverrides(onboardingCompleted: true),
          placeDetailProvider.overrideWith(
            (ref, id) => Completer<PlaceDetail>().future,
          ),
        ],
        child: const MaterialApp(home: PlaceDetailsScreen(placeId: 'p1')),
      ),
    );
    await tester.pump();

    expect(find.byType(AppShimmer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('details-hero-loading-back')),
      findsOneWidget,
    );
  });
}
