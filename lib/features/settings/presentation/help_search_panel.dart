import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
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

  /// Set once a search has been running long enough to look stuck.
  ///
  /// Questions asked at the same moment queue for the same model on the
  /// server rather than being answered from the weaker lexical search, so a
  /// few seconds of waiting is a normal outcome and worth naming.
  bool _slow = false;
  int _generation = 0;
  Timer? _slowTimer;

  static const _slowAfter = Duration(seconds: 2, milliseconds: 500);

  @override
  void dispose() {
    _slowTimer?.cancel();
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
      _slow = false;
      _result = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted && _busy && generation == _generation) {
        setState(() => _slow = true);
      }
    });
    try {
      final result = await ref.read(helpRepositoryProvider).search(query);
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } on Object {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  static const _iconSize = 34.0;
  static const _buttonHeight = 48.0;

  // Same field look as the blog comment box in the design.
  static const _fieldFill = Color(0xFFE8E8E8);
  static const _fieldEdge = Color(0xFFD9D9DB);

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

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
            padding: const EdgeInsets.all(AppSpacing.md),
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
                      // The SVG draws its square 3/36 inside its own box: pull
                      // it left by that much so the square, not the box,
                      // lines up with the field and buttons below.
                      Transform.translate(
                        offset: const Offset(-_iconSize * 3 / 36, 0),
                        child: Image.asset(
                          AppIconography.settingsHelpAssistant,
                          width: _iconSize,
                          height: _iconSize,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Помощник по справке',
                              style: AppTypography.settingsRowTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Опишите проблему - получите решение',
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                color: AppColors.settingsSecondaryInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Same width as the field and the buttons.
                  const SettingsHairline(),
                  const SizedBox(height: AppSpacing.sm),
                  Stack(
                    children: [
                      TextField(
                        controller: _query,
                        focusNode: _queryFocus,
                        maxLength: helpQueryMaxLength,
                        minLines: 3,
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
                          fillColor: _fieldFill,
                          counterText: '',
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            12,
                            14,
                            26,
                          ),
                          border: _fieldBorder(_fieldEdge),
                          enabledBorder: _fieldBorder(_fieldEdge),
                          focusedBorder: _fieldBorder(AppColors.accentBlue),
                        ),
                        onSubmitted: (_) => _search(),
                        onChanged: (_) => setState(() {
                          _generation++;
                          _result = null;
                          _failed = false;
                        }),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 8,
                        child: Text(
                          '${_query.text.characters.length}/$helpQueryMaxLength',
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryInk,
                      foregroundColor: Colors.white,
                      // The design keeps it black even before anything is typed.
                      disabledBackgroundColor: AppColors.primaryInk,
                      disabledForegroundColor: Colors.white,
                      // No invisible tap-target margin: it added itself to the
                      // gaps and made them uneven. 48 dp is the target anyway.
                      minimumSize: const Size.fromHeight(_buttonHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: _busy || _query.text.trim().isEmpty
                        ? null
                        : _search,
                    child: _busy
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Ищем в справке…'),
                            ],
                          )
                        : const Text('Найти инструкцию'),
                  ),
                  if (_busy && _slow) ...[
                    const SizedBox(height: 8),
                    const Text(
                      key: ValueKey('help-search-slow'),
                      'Сейчас много запросов — ищем по очереди, чтобы ответ '
                      'был точным. Это займёт несколько секунд.',
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ],
                  if (_failed || result != null || (_busy && _slow))
                    const SizedBox(height: AppSpacing.xs),
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
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentBlue,
                      side: const BorderSide(
                        color: AppColors.accentBlue,
                        width: 1.5,
                      ),
                      minimumSize: const Size.fromHeight(_buttonHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      textStyle: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

/// The design caps the question at 120 characters (a question, not a story).
const helpQueryMaxLength = 120;

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
