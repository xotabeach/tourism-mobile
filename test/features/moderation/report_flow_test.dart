import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_details_screen.dart';
import 'package:tourism_mobile/features/moderation/application/moderation_providers.dart';
import 'package:tourism_mobile/features/moderation/domain/content_report.dart';

import '../../support/test_overrides.dart';

/// Жалоба на комментарий: щит есть только на чужих, шторка отдаёт причину и
/// пояснение, повторная жалоба честно говорит, что она уже есть.
class _RecordingModerationRepository implements ModerationRepository {
  final calls = <Map<String, Object?>>[];
  bool nextIsRepeat = false;

  @override
  Future<ContentReport> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) async {
    calls.add({
      'target': targetType.apiValue,
      'id': targetId,
      'reason': reason.apiValue,
      'comment': comment,
    });
    return ContentReport(
      id: 'report-1',
      reason: reason.apiValue,
      status: 'new',
      alreadyReported: nextIsRepeat,
    );
  }
}

class _StubArticlesRepository implements ArticlesRepository {
  _StubArticlesRepository(this.comments);

  final List<ArticleComment> comments;

  @override
  Future<Article> getArticle(String id) async => Article(
    id: 'article-1',
    title: 'Не маршрут, а приключение',
    status: ArticleStatus.published,
    authorUserId: 'author-1',
    authorDisplayName: 'Никита',
    createdAt: DateTime.utc(2026, 9, 4),
  );

  @override
  Future<ArticleListPage> listRelated(String articleId) async =>
      const ArticleListPage(items: [], total: 0);

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) async => ArticleCommentPage(items: comments, total: comments.length);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

ArticleComment _comment({required String id, required String authorId}) =>
    ArticleComment(
      id: id,
      articleId: 'article-1',
      authorUserId: authorId,
      authorDisplayName: 'Мария',
      body: 'Купите курсы по ссылке в профиле',
      status: ArticleCommentStatus.published,
      createdAt: DateTime.utc(2026, 9, 4),
    );

Future<_RecordingModerationRepository> _pump(
  WidgetTester tester, {
  required List<ArticleComment> comments,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 2400);
  addTearDown(() {
    tester.view
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  final moderation = _RecordingModerationRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        articlesRepositoryProvider.overrideWithValue(
          _StubArticlesRepository(comments),
        ),
        moderationRepositoryProvider.overrideWithValue(moderation),
      ],
      child: const MaterialApp(
        home: ArticleDetailsScreen(articleId: 'article-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return moderation;
}

void main() {
  testWidgets('reporting a comment sends the reason and the note', (
    tester,
  ) async {
    final moderation = await _pump(
      tester,
      comments: [_comment(id: 'c1', authorId: 'someone-else')],
    );

    final shield = find.byKey(const ValueKey('article-comment-report-c1'));
    expect(shield, findsOneWidget);
    await tester.ensureVisible(shield);
    await tester.tap(shield);
    await tester.pumpAndSettle();

    // Пока причина не выбрана, отправлять нечего.
    final submit = find.byKey(const ValueKey('report-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.text('Спам или реклама'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Реклама курсов');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(moderation.calls, [
      {
        'target': 'article_comment',
        'id': 'c1',
        'reason': 'spam',
        'comment': 'Реклама курсов',
      },
    ]);
    expect(find.textContaining('жалоба отправлена'), findsOneWidget);
  });

  testWidgets('a repeat report says the complaint is already in the queue', (
    tester,
  ) async {
    final moderation = await _pump(
      tester,
      comments: [_comment(id: 'c1', authorId: 'someone-else')],
    );
    moderation.nextIsRepeat = true;

    final shield = find.byKey(const ValueKey('article-comment-report-c1'));
    await tester.ensureVisible(shield);
    await tester.tap(shield);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оскорбления или травля'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('уже жаловались'), findsOneWidget);
  });

  testWidgets('there is no shield on your own comment', (tester) async {
    await _pump(tester, comments: [_comment(id: 'c1', authorId: 'mock-user')]);

    expect(
      find.byKey(const ValueKey('article-comment-report-c1')),
      findsNothing,
    );
  });
}
