import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_editor_screen.dart';

import '../../support/test_overrides.dart';

class _FakeRepository implements ArticlesRepository {
  final createdTitles = <String>[];
  List<String> lastTags = const [];

  @override
  Future<Article> createDraft({
    required String title,
    String? relatedRouteId,
    String? relatedPlaceId,
    List<String> tags = const [],
    List<ArticleBlockDraft> blocks = const [],
  }) async {
    createdTitles.add(title);
    lastTags = tags;
    return Article(
      id: 'article-1',
      title: title,
      status: ArticleStatus.draft,
      authorUserId: 'mock-user',
      authorDisplayName: 'Вы',
      createdAt: DateTime.utc(2026, 9, 1),
      tags: tags,
      blocks: [
        for (var index = 0; index < blocks.length; index++)
          ArticleBlock(
            id: 'server-$index',
            position: index,
            blockType: blocks[index].blockType,
            textContent: blocks[index].textContent,
          ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Future<_FakeRepository> _pumpEditor(WidgetTester tester) async {
  // The editor is one long ListView; a short surface simply never builds the
  // content section, so give it a tall phone-width window.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 2400);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repository = _FakeRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        articlesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: ArticleEditorScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('starts empty, with the submit button disabled', (tester) async {
    await _pumpEditor(tester);

    // Название экрана в теле, а в шапке — вордмарк (макет 2026-09-04).
    expect(find.text('КРЫМТРИП'), findsOneWidget);
    expect(find.textContaining('Добавьте первый блок'), findsOneWidget);

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('editor-publish')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('adding a text block replaces the hint with an editable tile', (
    tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('Добавьте первый блок'), findsNothing);
    expect(find.text('ТЕКСТ'), findsOneWidget);
  });

  testWidgets('each block type adds its own labelled tile', (tester) async {
    await _pumpEditor(tester);

    for (final icon in [
      Icons.notes_rounded,
      Icons.image_outlined,
      Icons.format_quote_rounded,
      Icons.format_list_bulleted_rounded,
      Icons.horizontal_rule_rounded,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
    }

    expect(find.text('ТЕКСТ'), findsOneWidget);
    expect(find.text('КАРТИНКА'), findsOneWidget);
    expect(find.text('ЦИТАТА'), findsOneWidget);
    expect(find.text('СПИСОК'), findsOneWidget);
    expect(find.text('РАЗДЕЛИТЕЛЬ'), findsOneWidget);
  });

  testWidgets('deleting a block removes its tile', (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.format_quote_rounded));
    await tester.pumpAndSettle();
    expect(find.text('ЦИТАТА'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('ЦИТАТА'), findsNothing);
    expect(find.textContaining('Добавьте первый блок'), findsOneWidget);
  });

  testWidgets('a title plus content enables submitting', (tester) async {
    await _pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Черновик статьи');
    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Первый абзац');
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('editor-publish')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('the tag picker collapses to five with a toggle', (tester) async {
    await _pumpEditor(tester);

    expect(find.text('Показать все'), findsOneWidget);
    expect(find.text('Природа'), findsOneWidget);
    expect(find.text('Мнение'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tag-picker-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Мнение'), findsOneWidget);
    expect(find.text('Свернуть'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag-picker-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Мнение'), findsNothing);
  });

  testWidgets('a block tile starts collapsed and expands on tap', (
    tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();
    // A freshly added block opens straight away — otherwise there is nowhere
    // visible to type.
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('block-tile-block-0')));
    await tester.pumpAndSettle();
    // Collapsed: only the title field is left, plus the one-line preview.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('нажмите, чтобы написать'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('block-tile-block-0')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('blocks reorder by dragging the dots handle', (tester) async {
    await _pumpEditor(tester);

    // Два блока: текст, затем цитата.
    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.format_quote_rounded));
    await tester.pumpAndSettle();

    Iterable<String> labelOrder() => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((value) => value == 'ТЕКСТ' || value == 'ЦИТАТА');

    expect(labelOrder(), ['ТЕКСТ', 'ЦИТАТА']);

    // Свернём второй блок: добавленный открывается сам и высокий, из-за
    // чего перенос пришлось бы тащить сильно дальше.
    await tester.tap(find.byKey(const ValueKey('block-tile-block-1')));
    await tester.pumpAndSettle();

    // Тянем ручку второго блока вверх, за пределы первого.
    final handles = find.byType(ReorderableDragStartListener);
    expect(handles, findsNWidgets(2));
    final start = tester.getCenter(handles.at(1));
    final target = tester.getCenter(handles.at(0));
    final gesture = await tester.startGesture(start);
    // ReorderableDragStartListener начинает перенос сразу — долгое нажатие
    // не нужно. Двигаем по шагам: одним прыжком перенос не регистрируется.
    await tester.pump(const Duration(milliseconds: 16));
    final step = (target.dy - start.dy - 8) / 8;
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(labelOrder(), ['ЦИТАТА', 'ТЕКСТ']);
  });

  testWidgets('only the first five tapped tags reach the backend', (
    tester,
  ) async {
    final repository = await _pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Со всеми тегами');
    // Свёрнутый пикер показывает пять чипов — остальные за «Показать все».
    await tester.tap(find.byKey(const ValueKey('tag-picker-toggle')));
    await tester.pumpAndSettle();
    for (final tag in [
      'Природа',
      'Пешком',
      'С детьми',
      'Водопады',
      'Романтика',
      'Леса',
    ]) {
      await tester.tap(find.text(tag));
      await tester.pumpAndSettle();
    }
    // Let the autosave debounce fire.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(repository.lastTags, hasLength(ArticleLimits.maxTagsPerArticle));
    expect(repository.lastTags, isNot(contains('Леса')));
  });
}
