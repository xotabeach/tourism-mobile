import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/settings/application/support_providers.dart';
import 'package:tourism_mobile/features/settings/data/support_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SupportFaqItem {
  const SupportFaqItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.answer,
  });

  final String id;
  final String title;
  final String subtitle;
  final String answer;
}

const kRoutesNavigationFaq = <SupportFaqItem>[
  SupportFaqItem(
    id: 'difficulty',
    title: 'Уровень сложности',
    subtitle: 'Как понять, справлюсь ли я?',
    answer:
        'В карточке маршрута указана сложность (лёгкий/средний/сложный) и ключевые параметры — расстояние, набор высоты, тип покрытия и ориентировочное время прохождения.',
  ),
  SupportFaqItem(
    id: 'offline',
    title: 'Офлайн-прохождение',
    subtitle: 'Можно ли пройти маршрут без интернета?',
    answer:
        'Да: скачайте маршрут заранее в разделе «Оффлайн маршруты». Навигация по точкам работает из локального кеша.',
  ),
  SupportFaqItem(
    id: 'route-error',
    title: 'Ошибка на маршруте',
    subtitle: 'Куда сообщить о закрытой тропе или неточности?',
    answer:
        'Откройте «Сообщить об ошибке» → «Ошибка на маршруте» и опишите проблему. Мы проверим данные и обновим карточку.',
  ),
  SupportFaqItem(
    id: 'order',
    title: 'Порядок точек',
    subtitle: 'Обязательно ли идти строго по очереди?',
    answer:
        'Рекомендуем порядок из карточки, но отдельные остановки можно пропустить. Прогресс сохранится по отмеченным точкам.',
  ),
  SupportFaqItem(
    id: 'season',
    title: 'Сезонность',
    subtitle: 'Как узнать, доступен ли маршрут сейчас?',
    answer:
        'В карточке маршрута и места указана сезонность и предупреждения. Перед выходом сверяйте погоду и закрытия троп.',
  ),
];

List<Widget> _supportActionRows(BuildContext context) {
  return [
    SettingsNavTile(
      title: 'Сообщить об ошибке',
      subtitle: 'На маршруте или в приложении',
      iconAsset: AppIconography.settingsReport,
      onTap: () => context.pushNamed(AppRouteNames.settingsReport),
    ),
    SettingsNavTile(
      title: 'Оценить приложение',
      subtitle: 'Это поможет нам в развитии',
      iconAsset: AppIconography.settingsRate,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оценка приложения — позже')),
        );
      },
    ),
    SettingsChatCta(onTap: () => context.pushNamed(AppRouteNames.settingsChat)),
  ];
}

class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Поддерка и обратная связь:',
      spaceChildren: false,
      children: [
        SettingsNavTile(
          title: 'Маршруты и навигация',
          iconAsset: AppIconography.settingsFaqRoutes,
          dense: true,
          onTap: () => context.pushNamed(
            AppRouteNames.settingsFaqCategory,
            pathParameters: {'category': 'routes'},
          ),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Вопросы по приложению',
          iconAsset: AppIconography.settingsFaqApp,
          dense: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Раздел появится позже')),
            );
          },
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Баллы ТревелПоинт и достижения',
          iconAsset: AppIconography.settingsTravelPoints,
          dense: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Раздел появится позже')),
            );
          },
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Подписка Тревел +',
          iconAsset: AppIconography.settingsTravelPlus,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsTravelPlus),
        ),
        const SizedBox(height: 16),
        const SettingsHairline(),
        const SizedBox(height: 16),
        ..._spacedActions(context),
      ],
    );
  }

  static List<Widget> _spacedActions(BuildContext context) {
    final rows = _supportActionRows(context);
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) out.add(const SizedBox(height: SettingsMetrics.rowGap));
      out.add(rows[i]);
    }
    return out;
  }
}

class SettingsFaqCategoryScreen extends StatelessWidget {
  const SettingsFaqCategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final items = category == 'routes'
        ? kRoutesNavigationFaq
        : const <SupportFaqItem>[];
    return SettingsScaffold(
      title: 'Маршруты и навигация:',
      spaceChildren: false,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: SettingsMetrics.rowGap),
          SettingsNavTile(
            title: items[i].title,
            subtitle: items[i].subtitle,
            onTap: () => context.pushNamed(
              AppRouteNames.settingsFaqAnswer,
              pathParameters: {'category': category, 'questionId': items[i].id},
            ),
          ),
        ],
        const SizedBox(height: 16),
        const SettingsHairline(),
        const SizedBox(height: 16),
        ...SettingsSupportScreen._spacedActions(context),
      ],
    );
  }
}

class SettingsFaqAnswerScreen extends StatelessWidget {
  const SettingsFaqAnswerScreen({
    super.key,
    required this.category,
    required this.questionId,
  });

  final String category;
  final String questionId;

  @override
  Widget build(BuildContext context) {
    final items = category == 'routes'
        ? kRoutesNavigationFaq
        : const <SupportFaqItem>[];
    SupportFaqItem? item;
    for (final candidate in items) {
      if (candidate.id == questionId) {
        item = candidate;
        break;
      }
    }
    item ??= items.isEmpty ? null : items.first;
    if (item == null) {
      return const SettingsScaffold(
        title: 'Вопрос',
        children: [Text('Вопрос не найден')],
      );
    }
    return SettingsScaffold(
      title: '${item.title}:',
      spaceChildren: false,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: AppShadows.settingsTile,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.settingsRowTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: AppTypography.settingsRowSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: AppShadows.settingsTile,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Асистент поддержки',
                  style: AppTypography.settingsRowSubtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SettingsColors.link,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.answer,
                  style: AppTypography.settingsRowSubtitle.copyWith(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.settingsInk,
                  ),
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...SettingsSupportScreen._spacedActions(context),
      ],
    );
  }
}

class SettingsChatScreen extends ConsumerStatefulWidget {
  const SettingsChatScreen({super.key});

  @override
  ConsumerState<SettingsChatScreen> createState() => _SettingsChatScreenState();
}

class _SettingsChatScreenState extends ConsumerState<SettingsChatScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 3);

  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  SupportTicket? _ticket;
  Timer? _refreshTimer;
  var _loading = true;
  var _sending = false;
  var _refreshing = false;
  var _lastViewInset = 0.0;
  var _lastMessageCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerFocus.addListener(_onComposerFocusChange);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _composerFocus.removeListener(_onComposerFocusChange);
    _composer.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerFocusChange() {
    if (_composerFocus.hasFocus) {
      _scrollToLatest();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshTimer();
      unawaited(_refreshTicket());
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didChangeMetrics() {
    _handleKeyboardInset();
  }

  void _handleKeyboardInset() {
    if (!mounted) {
      return;
    }
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final opened = inset > _lastViewInset + 1;
    _lastViewInset = inset;
    if (opened) {
      _scrollToLatest();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      final tickets = await repo.listTickets();
      final chat = tickets.where((t) => t.kind == 'chat').firstOrNull;
      if (chat != null) {
        _ticket = await repo.getTicket(chat.id);
        _lastMessageCount = _ticket?.messages.length ?? 0;
        _startRefreshTimer();
      }
    } on AppFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToLatest(animate: false);
      }
    }
  }

  void _startRefreshTimer() {
    if (_ticket == null || _refreshTimer != null) {
      return;
    }
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => unawaited(_refreshTicket()),
    );
  }

  void _scrollToLatest({bool animate = true}) {
    void go() {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (!animate || (_scrollController.position.pixels - target).abs() < 1) {
        _scrollController.jumpTo(target);
        return;
      }
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    }

    if (_scrollController.hasClients) {
      // Wait one frame so resizeToAvoidBottomInset can update extents.
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    });
  }

  void _adoptMessages(SupportTicket updated, {required bool scroll}) {
    final count = updated.messages.length;
    final grew = count > _lastMessageCount;
    _ticket = updated;
    _lastMessageCount = count;
    _error = null;
    if (scroll || grew) {
      _scrollToLatest();
    }
  }

  Future<void> _refreshTicket() async {
    final ticket = _ticket;
    if (!mounted || ticket == null || _sending || _refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final updated = await ref
          .read(supportRepositoryProvider)
          .getTicket(ticket.id);
      if (!mounted) {
        return;
      }
      setState(() => _adoptMessages(updated, scroll: false));
    } on AppFailure {
      return;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      if (_ticket == null) {
        final created = await repo.createTicket(
          kind: 'chat',
          subject: 'Чат поддержки',
          body: text,
        );
        if (!mounted) {
          return;
        }
        setState(() => _adoptMessages(created, scroll: true));
      } else {
        final message = await repo.addMessage(
          ticketId: _ticket!.id,
          body: text,
        );
        if (!mounted) {
          return;
        }
        setState(
          () => _adoptMessages(
            SupportTicket(
              id: _ticket!.id,
              kind: _ticket!.kind,
              subject: _ticket!.subject,
              status: _ticket!.status,
              routeId: _ticket!.routeId,
              createdAt: _ticket!.createdAt,
              updatedAt: message.createdAt,
              messages: [..._ticket!.messages, message],
            ),
            scroll: true,
          ),
        );
      }
      _composer.clear();
      // Keep the soft keyboard open for consecutive replies.
      _composerFocus.requestFocus();
      _startRefreshTimer();
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _composerFocus.requestFocus();
      }
      unawaited(_refreshTicket());
    }
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery updates are the most reliable keyboard signal in tests/devices.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _lastViewInset) {
      final opened = inset > _lastViewInset + 1;
      _lastViewInset = inset;
      if (opened) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToLatest();
          }
        });
      }
    }
    final messages = _ticket?.messages ?? const <SupportMessage>[];
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      SettingsMetrics.contentInset,
                      top + 8,
                      SettingsMetrics.contentInset,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SettingsTopBar(),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          const Center(
                            child: Text(
                              'Сегодня',
                              style: AppTypography.settingsRowSubtitle,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null)
                            Text(
                              _error!,
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          if (messages.isEmpty && _error == null)
                            Text(
                              'Напишите сообщение — создадим обращение в поддержку.',
                              style: AppTypography.settingsRowSubtitle.copyWith(
                                color: AppColors.settingsInk,
                              ),
                            ),
                          for (final message in messages) ...[
                            const SizedBox(height: 12),
                            _ChatBubble(message: message),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GestureDetector(
                    key: const ValueKey('chat-empty-space'),
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SettingsTextField(
                      controller: _composer,
                      focusNode: _composerFocus,
                      hintText: 'Сообщение…',
                      maxLength: 4000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_sending) {
                          unawaited(_send());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SettingsCircleIconButton(
                    icon: Icons.send_rounded,
                    onTap: _sending ? () {} : () => unawaited(_send()),
                    background: SettingsColors.accent,
                    iconColor: Colors.white,
                    size: 46,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.author == 'user';
    final time =
        '${message.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? SettingsColors.accent : AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isUser
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  const Text(
                    'Асистент поддержки',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: SettingsColors.link,
                    ),
                  ),
                if (!isUser) const SizedBox(height: 6),
                Text(
                  message.body,
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    color: isUser ? Colors.white : AppColors.settingsInk,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: AppFonts.rubik,
                    color: isUser
                        ? const Color(0xBFFFFFFF)
                        : AppColors.settingsSecondaryInk,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsReportScreen extends StatelessWidget {
  const SettingsReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Сообщить об ошибке:',
      showSave: true,
      children: [
        SettingsNavTile(
          title: 'Ошибка на маршруте',
          iconAsset: AppIconography.settingsFaqRoutes,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsReportRoute),
        ),
        SettingsNavTile(
          title: 'Ошибка в приложении',
          iconAsset: AppIconography.settingsFaqApp,
          dense: true,
          onTap: () => context.pushNamed(AppRouteNames.settingsReportApp),
        ),
        SettingsNavTile(
          title: 'Оценить приложение',
          subtitle: 'Это поможет нам в развитии',
          iconAsset: AppIconography.settingsRate,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Оценка приложения — позже')),
            );
          },
        ),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class SettingsReportAppFormScreen extends ConsumerStatefulWidget {
  const SettingsReportAppFormScreen({super.key});

  @override
  ConsumerState<SettingsReportAppFormScreen> createState() =>
      _SettingsReportAppFormScreenState();
}

class _SettingsReportAppFormScreenState
    extends ConsumerState<SettingsReportAppFormScreen> {
  final _description = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _description.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Опишите проблему')));
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .createTicket(
            kind: 'app_error',
            subject: 'Ошибка в приложении',
            body: body,
          );
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRouteNames.settingsThanks));
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Ошибка в приложении:',
      showSave: true,
      spaceChildren: false,
      onSave: _busy ? null : _submit,
      children: [
        SettingsFormCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тип проблемы:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Приложение вылетает / зависает',
                      style: AppTypography.settingsRowSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Описание:',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 4,
                maxLength: 2000,
                style: AppTypography.settingsRowSubtitle.copyWith(
                  color: AppColors.settingsInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Опишите проблему максимально подробно',
                  hintStyle: AppTypography.settingsRowSubtitle,
                  filled: true,
                  fillColor: AppColors.elevatedSurface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: SettingsColors.hairline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: SettingsColors.hairline,
                    ),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Скриншот проблемы (рекомендуется):',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              SettingsDashedUpload(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Вложение скриншота — позже')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Устройство и версия (автоматически)',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Версия 0.32.1 (Бета). Iphone 16, IOS 27.',
                style: AppTypography.settingsRowSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsNavTile(
          title: 'Оценить приложение',
          subtitle: 'Это поможет нам в развитии',
          iconAsset: AppIconography.settingsRate,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Оценка приложения — позже')),
            );
          },
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class SettingsReportRouteFormScreen extends ConsumerStatefulWidget {
  const SettingsReportRouteFormScreen({super.key});

  @override
  ConsumerState<SettingsReportRouteFormScreen> createState() =>
      _SettingsReportRouteFormScreenState();
}

class _SettingsReportRouteFormScreenState
    extends ConsumerState<SettingsReportRouteFormScreen> {
  final _description = TextEditingController();
  var _routeSelected = false;
  var _pickerOpen = false;
  var _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _description.text.trim();
    if (!_routeSelected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите маршрут')));
      return;
    }
    if (body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Опишите проблему')));
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .createTicket(
            kind: 'route_error',
            subject: 'Ошибка на маршруте: Гора Чок-Сары-Кая',
            body: body,
          );
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRouteNames.settingsThanks));
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Ошибка в маршруте:',
      showSave: true,
      spaceChildren: false,
      onSave: _busy ? null : _submit,
      children: [
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Проблемный маршрут:',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Material(
                color: _routeSelected
                    ? const Color(0xFFF2F2F2)
                    : SettingsColors.fieldFill,
                borderRadius: BorderRadius.circular(
                  _routeSelected ? 12 : AppRadii.capsule,
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _pickerOpen = !_pickerOpen),
                      borderRadius: BorderRadius.circular(
                        _routeSelected ? 12 : AppRadii.capsule,
                      ),
                      child: SizedBox(
                        height: _routeSelected ? 56 : 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              if (_routeSelected)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    AppImages.coastalBayHills,
                                    width: 44,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 44,
                                      height: 40,
                                      color: AppColors.controlSurface,
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: Color(0xFF9A9A9A),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _routeSelected
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Гора Чок-Сары-Кая',
                                            style: AppTypography
                                                .settingsRowTitle
                                                .copyWith(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Опубликован: 12.05.26',
                                            style: AppTypography
                                                .settingsRowSubtitle
                                                .copyWith(fontSize: 11),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Искать маршрут',
                                        style:
                                            AppTypography.settingsRowSubtitle,
                                      ),
                              ),
                              Icon(
                                _pickerOpen
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_pickerOpen)
                      for (var i = 0; i < 4; i++) ...[
                        const Divider(height: 1, color: Color(0xFFEDEDED)),
                        InkWell(
                          onTap: () => setState(() {
                            _routeSelected = true;
                            _pickerOpen = false;
                          }),
                          child: SizedBox(
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      AppImages.coastalBayHills,
                                      width: 44,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 44,
                                        height: 40,
                                        color: AppColors.controlSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Гора Чок-Сары-Кая',
                                          style: AppTypography.settingsRowTitle
                                              .copyWith(fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Опубликован: 12.05.26',
                                          style: AppTypography
                                              .settingsRowSubtitle
                                              .copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тип проблемы:',
                      style: AppTypography.settingsRowTitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Тропа закрыта / перекрыта',
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Описание:',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 4,
                maxLength: 2000,
                style: AppTypography.settingsRowSubtitle.copyWith(
                  color: AppColors.settingsInk,
                ),
                decoration: InputDecoration(
                  hintText: 'Опишите проблему максимально подробно',
                  hintStyle: AppTypography.settingsRowSubtitle,
                  filled: true,
                  fillColor: AppColors.elevatedSurface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: SettingsColors.hairline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: SettingsColors.hairline,
                    ),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Скриншот проблемы (рекомендуется):',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              SettingsDashedUpload(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Вложение скриншота — позже')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Устройство и версия (автоматически)',
                style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Версия 0.32.1 (Бета). Iphone 16, IOS 27.',
                style: AppTypography.settingsRowSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsNavTile(
          title: 'Оценить приложение',
          subtitle: 'Это поможет нам в развитии',
          iconAsset: AppIconography.settingsRate,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Оценка приложения — позже')),
            );
          },
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class SettingsThanksScreen extends StatelessWidget {
  const SettingsThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      showSave: true,
      spaceChildren: false,
      children: [
        const SizedBox(height: 48),
        const Center(
          child: Icon(
            Icons.favorite_border_rounded,
            size: 96,
            color: Color(0xFFD8D8D8),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text(
            'Спасибо за помощь!',
            style: AppTypography.settingsSectionTitle,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Благодаря вашей помощи мы становимся лучше',
            textAlign: TextAlign.center,
            style: AppTypography.settingsRowSubtitle,
          ),
        ),
        const SizedBox(height: 20),
        SettingsPrimaryButton(
          label: 'Вернуться на главную',
          onPressed: () => context.goNamed(AppRouteNames.home),
        ),
      ],
    );
  }
}
