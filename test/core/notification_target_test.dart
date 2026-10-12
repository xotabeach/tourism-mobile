import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/components/focus_highlight.dart';
import 'package:tourism_mobile/core/notifications/notification_target.dart';
import 'package:tourism_mobile/features/settings/data/notifications_repository.dart';
import 'package:tourism_mobile/routing/app_router.dart';

// FRONTEND-74: a notification opens what it is about, right at the comment.

GoRouter _router() {
  Widget page(GoRouterState state) =>
      Text(state.uri.toString(), textDirection: TextDirection.ltr);
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        name: AppRouteNames.routeDetails,
        path: '/routes/:id',
        builder: (_, state) => page(state),
      ),
      GoRoute(
        name: AppRouteNames.articleDetails,
        path: '/articles/:id',
        builder: (_, state) => page(state),
      ),
      GoRoute(
        name: AppRouteNames.userProfile,
        path: '/users/:userId',
        builder: (_, state) => page(state),
      ),
    ],
  );
}

Future<String> _open(
  WidgetTester tester, {
  required String? type,
  required String? id,
  String? anchor,
}) async {
  final router = _router();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  final opened = openNotificationTarget(
    router,
    targetType: type,
    targetId: id,
    anchorId: anchor,
  );
  await tester.pumpAndSettle();
  if (!opened) return 'none';
  // Each test page prints the location it was opened with.
  return tester.widgetList<Text>(find.byType(Text)).last.data!;
}

void main() {
  testWidgets('an article comment opens the article at the comment', (
    tester,
  ) async {
    expect(
      await _open(tester, type: 'article', id: 'a1', anchor: 'c9'),
      '/articles/a1?comment=c9',
    );
  });

  testWidgets('a review opens the route on its reviews, at the review', (
    tester,
  ) async {
    expect(
      await _open(tester, type: 'route', id: 'r1', anchor: 'v2'),
      '/routes/r1?tab=reviews&review=v2',
    );
  });

  testWidgets('without an anchor the object opens at the top', (tester) async {
    expect(await _open(tester, type: 'route', id: 'r1'), '/routes/r1');
    expect(await _open(tester, type: 'article', id: 'a1'), '/articles/a1');
  });

  testWidgets('a profile like opens the profile', (tester) async {
    expect(await _open(tester, type: 'user', id: 'u1'), '/users/u1');
  });

  testWidgets('nothing to open is not an error', (tester) async {
    expect(await _open(tester, type: 'article', id: null), 'none');
    expect(await _open(tester, type: null, id: 'x'), 'none');
  });

  test('the inbox reads the anchor', () {
    final item = InboxNotification.fromJson({
      'id': 'n1',
      'kind': 'article_comment',
      'title': 'Новый комментарий',
      'body': '',
      'target_type': 'article',
      'target_id': 'a1',
      'anchor_id': 'c9',
      'is_read': false,
      'created_at': '2026-10-13T10:00:00Z',
    });
    expect(item.anchorId, 'c9');
    expect(item.copyWith(isUnread: false).anchorId, 'c9');
  });

  testWidgets('the focused item scrolls into view and lights up', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // As on the route page: the reviews are one box in the scroll.
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (var i = 0; i < 30; i++)
                      FocusHighlight(
                        active: i == 25,
                        child: SizedBox(height: 80, child: Text('item $i')),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('item 25').hitTestable(), findsOneWidget);
    final lit = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('item 25'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((lit.decoration! as BoxDecoration).color, FocusHighlight.color);
    await tester.pump(const Duration(seconds: 3));
  });
}
