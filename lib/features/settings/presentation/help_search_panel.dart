import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
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
  final _queryFocus = FocusNode();
  HelpSearchResult? _result;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
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
    final radius = BorderRadius.circular(AppRadii.settingsTile);
    return Padding(
      padding: const EdgeInsets.only(bottom: SettingsMetrics.rowGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppShadows.settingsTile,
        ),
        child: Material(
          key: const ValueKey('support-help-card'),
          color: AppColors.elevatedSurface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: AppTypography.settingsRowSubtitle.copyWith(
                color: AppColors.settingsInk,
                height: 1.4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.accentBlueIcon,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Помощник по справке',
                          style: AppTypography.settingsRowTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Опишите проблему — предложим подходящие инструкции.',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _query,
                    focusNode: _queryFocus,
                    maxLength: 400,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      color: AppColors.settingsInk,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Например: не начислились баллы',
                      hintStyle: AppTypography.settingsRowSubtitle,
                      filled: true,
                      fillColor: AppColors.pageSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.accentBlue,
                        ),
                      ),
                      counterStyle: AppTypography.settingsRowSubtitle.copyWith(
                        fontSize: 11,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                    onChanged: (_) => setState(() {
                      _generation++;
                      _result = null;
                      _failed = false;
                    }),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _busy || _query.text.trim().isEmpty
                        ? null
                        : _search,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.search_rounded, size: 19),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _busy ? 'Ищем в справке…' : 'Найти инструкцию',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      const Text('Возможно, помогут эти инструкции:'),
                      Text('Найдено статей: ${result.articles.length}'),
                      for (final article in result.articles)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(article.title),
                          titleTextStyle: AppTypography.settingsRowTitle
                              .copyWith(fontSize: 14),
                          subtitleTextStyle: AppTypography.settingsRowSubtitle
                              .copyWith(height: 1.4),
                          subtitle: Text(
                            article.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.accentBlueIcon,
                          ),
                          onTap: () => Navigator.of(context).push<void>(
                            CupertinoPageRoute<void>(
                              builder: (_) =>
                                  HelpArticleScreen(article: article),
                            ),
                          ),
                        ),
                    ],
                    TextButton(
                      onPressed: () {
                        _queryFocus.requestFocus();
                        _query.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _query.text.length,
                        );
                      },
                      child: const Text('Уточнить вопрос'),
                    ),
                  ],
                  TextButton(
                    onPressed: () =>
                        widget.onContactSupport(_query.text.trim()),
                    child: const Text('Написать оператору'),
                  ),
                ],
              ),
            ),
          ),
        ),
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
