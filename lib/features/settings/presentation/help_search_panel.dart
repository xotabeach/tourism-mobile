import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/settings/data/help_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

/// A search assistant, not a generative chat. Operator messages remain explicit.
class HelpSearchPanel extends ConsumerStatefulWidget {
  const HelpSearchPanel({required this.onContactSupport, super.key});

  final ValueChanged<String> onContactSupport;

  @override
  ConsumerState<HelpSearchPanel> createState() => _HelpSearchPanelState();
}

class _HelpSearchPanelState extends ConsumerState<HelpSearchPanel> {
  final _query = TextEditingController();
  HelpSearchResult? _result;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (_busy || query.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
    });
    try {
      final result = await ref.read(helpRepositoryProvider).search(query);
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } on Object {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Помощник по справке'),
          const SizedBox(height: 8),
          const Text('Опишите проблему — предложим подходящие инструкции.'),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            maxLength: 400,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Например: не начислились баллы',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {
              _generation++;
              _result = null;
              _failed = false;
            }),
          ),
          OutlinedButton(
            onPressed: _busy || _query.text.trim().isEmpty ? null : _search,
            child: Text(_busy ? 'Ищем в справке…' : 'Найти инструкцию'),
          ),
          if (_failed)
            const Text(
              'Поиск сейчас недоступен. Можно повторить, открыть разделы '
              'справки ниже или написать оператору.',
            ),
          if (result != null) ...[
            if (!result.available)
              const Text(
                'Для этой версии ещё нет опубликованных инструкций в поиске. '
                'Можно открыть справку ниже или обратиться к оператору.',
              )
            else if (result.articles.isEmpty)
              const Text(
                'Подходящая инструкция не найдена. Уточните вопрос '
                'или напишите оператору.',
              )
            else ...[
              Text('Найдено статей: ${result.articles.length}'),
              for (final article in result.articles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(article.title),
                  subtitle: Text(article.excerpt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    CupertinoPageRoute<void>(
                      builder: (_) => HelpArticleScreen(article: article),
                    ),
                  ),
                ),
            ],
          ],
          TextButton(
            onPressed: () => widget.onContactSupport(_query.text.trim()),
            child: const Text('Написать оператору'),
          ),
          const SizedBox(height: 16),
          const SettingsHairline(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class HelpArticleScreen extends ConsumerStatefulWidget {
  const HelpArticleScreen({required this.article, super.key});

  final HelpArticle article;

  @override
  ConsumerState<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends ConsumerState<HelpArticleScreen> {
  late Future<HelpArticle> _article;

  @override
  void initState() {
    super.initState();
    _article = ref.read(helpRepositoryProvider).read(widget.article);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Инструкция',
    children: [
      FutureBuilder<HelpArticle>(
        future: _article,
        builder: (context, snapshot) {
          final article = snapshot.data;
          if (snapshot.hasError) {
            return Column(
              children: [
                const Text(
                  'Не удалось открыть статью. Возможно, она больше '
                  'недоступна для этой версии приложения.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _article = ref
                        .read(helpRepositoryProvider)
                        .read(widget.article);
                  }),
                  child: const Text('Повторить'),
                ),
              ],
            );
          }
          if (article == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Справка КрымТрип · редакция ${article.revision}'),
              const SizedBox(height: 16),
              Text(article.body ?? ''),
            ],
          );
        },
      ),
    ],
  );
}
