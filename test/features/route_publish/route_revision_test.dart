import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';
import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

RouteSummary _route(String status, {String? revision, String? reason}) =>
    RouteSummary.fromJson({
      'id': 'route-1',
      'name': 'Алушта',
      'slug': 'alushta',
      'short_description': '',
      'stops_count': 2,
      'visibility': 'public',
      'publication_status': status,
      'revision_status': revision,
      'rejection_reason': reason,
    });

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('the edit state survives the local draft and can be cleared', () {
    const draft = RouteDraft(
      serverId: 'route-1',
      publicationStatus: RoutePublicationStatus.published,
      revisionStatus: RouteRevisionStatus.rejected,
      revisionRejection: 'Уточните описание',
    );

    final restored = RouteDraft.fromJson(draft.toJson());
    expect(restored.editsPublished, isTrue);
    expect(restored.revisionStatus, RouteRevisionStatus.rejected);
    expect(restored.revisionRejection, 'Уточните описание');

    final cleared = restored.copyWith(clearRevision: true);
    expect(cleared.revisionStatus, isNull);
    expect(cleared.revisionRejection, isNull);
    // A copy that left the server (a conflict kept as a new draft) is no
    // longer anyone's edit.
    expect(restored.copyWith(clearServer: true).revisionStatus, isNull);
    // An unknown state from a newer server reads as «no edit», not a guess.
    expect(RouteRevisionStatus.fromApi('archived'), isNull);
    expect(const RouteDraft().editsPublished, isFalse);
  });

  test('my routes name the state of the edit, not of the route', () {
    expect(routeStatusLabel(_route('published')), isNull);
    expect(
      routeStatusLabel(_route('published', revision: 'pending_review')),
      'Правка на проверке',
    );
    expect(
      routeStatusLabel(_route('published', revision: 'rejected')),
      'Правку вернули',
    );
    expect(
      routeStatusLabel(_route('published', revision: 'draft')),
      'Правка не отправлена',
    );
    // A route that is not published keeps its own label.
    expect(routeStatusLabel(_route('pending_review')), 'На модерации');
    final cached = RouteSummary.fromJson(
      _route('published', revision: 'rejected', reason: 'Фото').toJson(),
    );
    expect(cached.revisionStatus, 'rejected');
    expect(cached.rejectionReason, 'Фото');
  });

  testWidgets('the editor of a published route sends an edit', (tester) async {
    var sent = 0;
    var saved = 0;
    await tester.pumpWidget(
      _host(
        PublishRouteActions(
          u: (value) => value,
          publishing: false,
          saving: false,
          editsPublished: true,
          onPublish: () => sent++,
          onSave: () => saved++,
        ),
      ),
    );

    expect(find.text('Опубликовать маршрут'), findsNothing);
    await tester.tap(find.text('Отправить на проверку'));
    await tester.tap(find.text('Сохранить правку'));
    expect((sent, saved), (1, 1));
  });

  testWidgets('a new route keeps the publish and draft buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PublishRouteActions(
          u: (value) => value,
          publishing: false,
          saving: false,
          onPublish: () {},
          onSave: () {},
        ),
      ),
    );

    expect(find.text('Опубликовать маршрут'), findsOneWidget);
    expect(find.text('Сохранить черновик'), findsOneWidget);
  });

  testWidgets('the notice says the catalogue keeps the old version', (
    tester,
  ) async {
    var discarded = 0;
    await tester.pumpWidget(
      _host(
        PublishedRouteEditNotice(
          u: (value) => value,
          status: RouteRevisionStatus.pendingReview,
          onDiscard: () => discarded++,
        ),
      ),
    );
    expect(
      find.text('Правка на проверке, в каталоге прежняя версия'),
      findsOneWidget,
    );
    await tester.tap(find.text('Отменить правку'));
    expect(discarded, 1);

    await tester.pumpWidget(
      _host(
        PublishedRouteEditNotice(
          u: (value) => value,
          status: RouteRevisionStatus.rejected,
          rejection: 'Опубликуйте как новый маршрут',
          onDiscard: () {},
        ),
      ),
    );
    expect(find.text('Правку вернули на доработку'), findsOneWidget);
    expect(
      find.textContaining('Опубликуйте как новый маршрут'),
      findsOneWidget,
    );

    // Nothing saved yet: there is no edit to drop, and no scary warning.
    await tester.pumpWidget(
      _host(PublishedRouteEditNotice(u: (value) => value, status: null)),
    );
    expect(find.text('Маршрут опубликован'), findsOneWidget);
    expect(find.text('Отменить правку'), findsNothing);
    expect(find.textContaining('останется в каталоге'), findsOneWidget);
  });

  test('a review written before the route changed says so', () {
    Map<String, dynamic> review({bool? before}) => {
      'id': 'r1',
      'route_id': 'route-1',
      'author_user_id': 'u1',
      'body': 'Красиво',
      'rating': 5,
      'created_at': '2026-10-09T08:00:00Z',
      'before_route_update': ?before,
    };

    expect(
      RouteReview.fromJson(review(before: true)).beforeRouteUpdate,
      isTrue,
    );
    expect(RouteReview.fromJson(review()).beforeRouteUpdate, isFalse);
  });
}
