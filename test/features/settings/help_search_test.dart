import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/data/help_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/help_search_panel.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

const _article = HelpArticle(
  id: 'points-earn',
  revision: 1,
  appVersion: '0.2.31',
  title: 'Баллы',
  excerpt: 'Баллы получает автор.',
  body: 'Полный текст проверенной инструкции.',
);

class _HelpFake implements HelpRepository {
  HelpSearchResult result = const HelpSearchResult(
    available: true,
    articles: [_article],
  );
  Completer<HelpSearchResult>? pending;
  bool failRead = false;
  bool failSearch = false;
  final queries = <String>[];
  int reads = 0;

  @override
  Future<HelpSearchResult> search(String query) async {
    queries.add(query);
    if (failSearch) throw StateError('fixture offline');
    return pending == null ? result : pending!.future;
  }

  @override
  Future<HelpArticle> read(HelpArticle article) async {
    reads++;
    if (failRead) throw StateError('fixture withdrawn');
    return _article;
  }
}

void main() {
  Future<void> pumpPanel(
    WidgetTester tester,
    _HelpFake repo, {
    ValueChanged<String>? onContact,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [helpRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HelpSearchPanel(onContactSupport: onContact ?? (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'баллы');
    await tester.pump();
    await tester.tap(find.text('Найти инструкцию'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows actual results and rechecks edition when opening source', (
    tester,
  ) async {
    final repo = _HelpFake();
    await pumpPanel(tester, repo);
    expect(repo.queries, isEmpty);
    await search(tester);
    expect(repo.queries, ['баллы']);
    expect(find.text('Найдено статей: 1'), findsOneWidget);
    await tester.tap(find.text('Баллы'));
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    expect(find.text(_article.body!), findsOneWidget);
    expect(find.text('Справка КрымТрип · редакция 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('withdrawn source is not shown from the search preview', (
    tester,
  ) async {
    final repo = _HelpFake()..failRead = true;
    await pumpPanel(tester, repo);
    await search(tester);
    await tester.tap(find.text('Баллы'));
    await tester.pumpAndSettle();
    expect(find.text(_article.body!), findsNothing);
    expect(find.textContaining('Не удалось открыть статью'), findsOneWidget);
  });

  testWidgets('no match and unpublished build are different states', (
    tester,
  ) async {
    final repo = _HelpFake()
      ..result = const HelpSearchResult(available: true, articles: []);
    await pumpPanel(tester, repo);
    await search(tester);
    expect(
      find.textContaining('Подходящая инструкция не найдена'),
      findsOneWidget,
    );
    repo.result = const HelpSearchResult(available: false, articles: []);
    await tester.tap(find.text('Найти инструкцию'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ещё нет опубликованных'), findsOneWidget);
    expect(find.textContaining('Найдено статей'), findsNothing);
  });

  testWidgets('late response cannot replace a changed question', (
    tester,
  ) async {
    final repo = _HelpFake()..pending = Completer<HelpSearchResult>();
    await pumpPanel(tester, repo);
    await tester.enterText(find.byType(TextField), 'баллы');
    await tester.pump();
    await tester.tap(find.text('Найти инструкцию'));
    await tester.pump();
    expect(repo.queries, ['баллы']);
    await tester.enterText(find.byType(TextField), 'номер телефона');
    repo.pending!.complete(repo.result);
    await tester.pumpAndSettle();
    expect(find.text('Найдено статей: 1'), findsNothing);
  });

  testWidgets(
    'operator action transfers the question without sending a ticket',
    (tester) async {
      String? forwarded;
      final repo = _HelpFake();
      await pumpPanel(tester, repo, onContact: (value) => forwarded = value);
      await tester.enterText(find.byType(TextField), '  Мой вопрос  ');
      await tester.tap(find.text('Написать оператору'));
      expect(forwarded, 'Мой вопрос');
      expect(repo.queries, isEmpty);
      expect(repo.reads, 0);
    },
  );

  testWidgets('failure stays honest and retry is available', (tester) async {
    final repo = _HelpFake()..failSearch = true;
    await pumpPanel(tester, repo);
    await search(tester);
    expect(find.textContaining('Поиск сейчас недоступен'), findsOneWidget);
    repo.failSearch = false;
    await tester.tap(find.text('Найти инструкцию'));
    await tester.pumpAndSettle();
    expect(find.text('Найдено статей: 1'), findsOneWidget);
  });

  testWidgets('search is reachable from the support screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsSupportScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HelpSearchPanel), findsOneWidget);
    expect(find.text('Помощник по справке'), findsOneWidget);
  });
}
