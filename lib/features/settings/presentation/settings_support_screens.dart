import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/device/device_info.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/settings/application/support_providers.dart';
import 'package:tourism_mobile/features/settings/data/support_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Store review link. Always shown — the app has no live store listing yet,
/// so a missing URL surfaces as a notice on tap rather than hiding the row
/// entirely (a settings entry that silently disappears reads as a bug).
class RateAppTile extends ConsumerWidget {
  const RateAppTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final url = Platform.isIOS ? config.appStoreUrl : config.playStoreUrl;
    return SettingsNavTile(
      title: 'Оценить приложение',
      subtitle: 'Это поможет нам в развитии',
      iconAsset: AppIconography.settingsRate,
      onTap: () async {
        final uri = url == null ? null : Uri.tryParse(url);
        final opened =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) {
          showAppNotice(
            context,
            uri == null
                ? 'Приложение пока не опубликовано в маркете'
                : 'Не удалось открыть магазин приложений',
          );
        }
      },
    );
  }
}

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

const kAppQuestionsFaq = <SupportFaqItem>[
  SupportFaqItem(
    id: 'account',
    title: 'Смена номера телефона',
    subtitle: 'Как поменять номер, привязанный к аккаунту?',
    answer:
        'В разделе «Настройки профиля» откройте номер телефона и запросите смену — придёт код подтверждения на новый номер.',
  ),
  SupportFaqItem(
    id: 'notifications',
    title: 'Уведомления',
    subtitle: 'Почему не приходят пуш-уведомления?',
    answer:
        'Проверьте переключатель в «Уведомления» и разрешения приложения в системных настройках телефона. Часть уведомлений (например, о поддержке) всегда доступна внутри приложения, даже если push отключён.',
  ),
  SupportFaqItem(
    id: 'ai-chat',
    title: 'Подбор маршрута с ИИ',
    subtitle: 'Как работает чат-подбор?',
    answer:
        'ИИ уточняет предпочтения и предлагает маршрут из каталога КрымТрип — это не свободная генерация, а подбор среди проверенных данных. История чатов сохраняется в разделе «История чатов с ИИ».',
  ),
  SupportFaqItem(
    id: 'data',
    title: 'Данные и приватность',
    subtitle: 'Что происходит с моими данными при выходе из аккаунта?',
    answer:
        'Локально скачанные маршруты и черновики удаляются с устройства. Данные профиля на сервере сохраняются — повторный вход восстановит избранное, достижения и историю.',
  ),
];

const kTravelPointsFaq = <SupportFaqItem>[
  SupportFaqItem(
    id: 'earn',
    title: 'Как начисляются баллы',
    subtitle: 'За что дают ТревелПоинты?',
    answer:
        'Сейчас +5 баллов начисляется за лайк профиля и за добавление чужого маршрута в избранное (с задержкой около 6 часов). Начисление за пройденные маршруты появится позже.',
  ),
  SupportFaqItem(
    id: 'rank',
    title: 'Звание',
    subtitle: 'Как повысить звание в профиле?',
    answer:
        'Звание растёт по накопленным ТревелПоинтам — пороги видны в профиле рядом с прогрессом до следующего звания.',
  ),
  SupportFaqItem(
    id: 'achievements',
    title: 'Достижения',
    subtitle: 'Как получить достижение?',
    answer:
        'Часть достижений выдаётся автоматически при регистрации, остальные открываются по мере активности в приложении. Полный список — locked и полученные — доступен в профиле.',
  ),
  SupportFaqItem(
    id: 'leaderboard',
    title: 'Топ пользователей',
    subtitle: 'Как попасть в топ?',
    answer:
        'Место в топе считается по общей сумме ТревелПоинтов и обновляется вместе с начислением баллов.',
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
    const RateAppTile(),
    SettingsChatCta(onTap: () => context.pushNamed(AppRouteNames.settingsChat)),
  ];
}

class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Поддержка и обратная связь:',
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
          onTap: () => context.pushNamed(
            AppRouteNames.settingsFaqCategory,
            pathParameters: {'category': 'app'},
          ),
        ),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsNavTile(
          title: 'Баллы ТревелПоинт и достижения',
          iconAsset: AppIconography.settingsTravelPoints,
          dense: true,
          onTap: () => context.pushNamed(
            AppRouteNames.settingsFaqCategory,
            pathParameters: {'category': 'travel_points'},
          ),
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

List<SupportFaqItem> _faqItemsForCategory(String category) =>
    switch (category) {
      'routes' => kRoutesNavigationFaq,
      'app' => kAppQuestionsFaq,
      'travel_points' => kTravelPointsFaq,
      _ => const <SupportFaqItem>[],
    };

String _faqCategoryTitle(String category) => switch (category) {
  'routes' => 'Маршруты и навигация',
  'app' => 'Вопросы по приложению',
  'travel_points' => 'Баллы ТревелПоинт и достижения',
  _ => 'Вопросы',
};

class SettingsFaqCategoryScreen extends StatelessWidget {
  const SettingsFaqCategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final items = _faqItemsForCategory(category);
    return SettingsScaffold(
      title: '${_faqCategoryTitle(category)}:',
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
    final items = _faqItemsForCategory(category);
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
    if (!_composerFocus.hasFocus) {
      return;
    }
    // Parent AppShell Scaffold strips MediaQuery.viewInsets; extents update
    // across the keyboard animation, so retry while focus stays.
    _scrollToLatest(animate: true);
    _scrollToLatestSoon();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Raw view inset in logical pixels (survives parent Scaffold inset stripping).
  double _keyboardInset() {
    final view = View.of(context);
    return MediaQueryData.fromView(view).viewInsets.bottom;
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
    if (!mounted) {
      return;
    }
    final inset = _keyboardInset();
    final opened = inset > _lastViewInset + 1;
    _lastViewInset = inset;
    if (opened || (inset > 0 && _composerFocus.hasFocus)) {
      _scrollToLatest(animate: false);
      if (opened) {
        _scrollToLatestSoon();
      }
    }
  }

  void _scrollToLatestSoon() {
    for (final delay in const [
      Duration(milliseconds: 50),
      Duration(milliseconds: 160),
      Duration(milliseconds: 320),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !_composerFocus.hasFocus) {
          return;
        }
        _scrollToLatest(animate: false);
      });
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
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 0.5) {
        return;
      }
      if (!animate) {
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

    // Wait a frame so the shell Scaffold can shrink before we read extents.
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
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
      showAppNotice(context, error.message);
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
    final messages = _ticket?.messages ?? const <SupportMessage>[];
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      // Shell Scaffold already resizes for the keyboard and strips viewInsets.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _PinnedChatBrandBar(topInset: top),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsMetrics.contentInset,
                      12,
                      SettingsMetrics.contentInset,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          GestureDetector(
                            key: const ValueKey('chat-message-area'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _dismissKeyboard,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                    style: AppTypography.settingsRowSubtitle
                                        .copyWith(color: AppColors.error),
                                  ),
                                if (messages.isEmpty && _error == null)
                                  Text(
                                    'Напишите сообщение — создадим обращение в поддержку.',
                                    style: AppTypography.settingsRowSubtitle
                                        .copyWith(color: AppColors.settingsInk),
                                  ),
                                for (final message in messages) ...[
                                  const SizedBox(height: 12),
                                  _ChatBubble(message: message),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GestureDetector(
                    key: const ValueKey('chat-empty-space'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissKeyboard,
                    child: const SizedBox.expand(),
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

/// Pinned chat header: home-like brand styling, original back button size.
class _PinnedChatBrandBar extends StatelessWidget {
  const _PinnedChatBrandBar({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageSurface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.mistDark.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            SettingsMetrics.contentInset,
            topInset + 2,
            SettingsMetrics.contentInset,
            6,
          ),
          child: SizedBox(
            height: SettingsMetrics.headerButton,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'КРЫМТРИП',
                  style: AppTypography.settingsBrand.copyWith(
                    color: AppColors.settingsBrand,
                    fontSize: 20,
                    height: 1,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SettingsCircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                    background: SettingsColors.circleButton,
                    iconColor: Colors.white,
                    iconSize: 18,
                    size: SettingsMetrics.headerButton,
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
        const RateAppTile(),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

const _appProblemTypes = <String>[
  'Приложение вылетает / зависает',
  'Ошибка отображения',
  'Проблема с авторизацией',
  'Другое',
];

const _routeProblemTypes = <String>[
  'Тропа закрыта / перекрыта',
  'Неточность на карте',
  'Опасный участок',
  'Устарела информация',
  'Другое',
];

class _ReportRouteOption {
  const _ReportRouteOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

String _reportRouteDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${(local.year % 100).toString().padLeft(2, '0')}';
}

/// Recent/active route executions are the only reliable source of "routes
/// this user actually has" without a dedicated route search — favors real
/// data over the previous hardcoded four-route picker.
List<_ReportRouteOption> _reportRouteOptions(
  List<RouteExecution> executions, {
  String? prefilledRouteId,
  String? prefilledRouteName,
}) {
  final seen = <String>{};
  final options = <_ReportRouteOption>[];
  if (prefilledRouteId != null && prefilledRouteId.isNotEmpty) {
    seen.add(prefilledRouteId);
    options.add(
      _ReportRouteOption(
        id: prefilledRouteId,
        title: prefilledRouteName ?? 'Выбранный маршрут',
        subtitle: 'Открыт из карточки маршрута',
      ),
    );
  }
  for (final execution in executions) {
    final routeId = execution.routeId;
    if (routeId == null || !seen.add(routeId)) {
      continue;
    }
    final subtitle = switch (execution.status) {
      RouteExecutionStatus.active => 'Проходится сейчас',
      RouteExecutionStatus.completed =>
        'Пройден: ${_reportRouteDate(execution.completedAt ?? execution.startedAt)}',
      RouteExecutionStatus.cancelled =>
        'Отменён: ${_reportRouteDate(execution.cancelledAt ?? execution.startedAt)}',
    };
    options.add(
      _ReportRouteOption(
        id: routeId,
        title: execution.routeName,
        subtitle: subtitle,
      ),
    );
  }
  return options;
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
  final _images = <XFile>[];
  String? _problemType;
  var _problemTypeOpen = false;
  var _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _description.text.trim();
    if (_problemType == null) {
      showAppNotice(context, 'Выберите тип проблемы');
      return;
    }
    if (body.isEmpty) {
      showAppNotice(context, 'Опишите проблему');
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final ticket = await repo.createTicket(
        kind: 'app_error',
        subject: 'Ошибка в приложении: $_problemType',
        body: body,
      );
      await uploadReportAttachments(repo, ticketId: ticket.id, images: _images);
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRouteNames.settingsThanks));
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      showAppNotice(context, error.message);
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
        _ReportOptionPicker(
          label: 'Тип проблемы:',
          value: _problemType,
          placeholder: 'Выберите тип проблемы',
          open: _problemTypeOpen,
          options: _appProblemTypes,
          onToggle: () => setState(() => _problemTypeOpen = !_problemTypeOpen),
          onSelect: (value) => setState(() {
            _problemType = value;
            _problemTypeOpen = false;
          }),
        ),
        const SizedBox(height: 12),
        _ReportDescriptionCard(controller: _description),
        const SizedBox(height: 12),
        _ReportScreenshotCard(
          isPhoto: false,
          images: _images,
          busy: _busy,
          onPick: () => pickReportImages(
            context,
            images: _images,
            onChanged: (next) => setState(() {
              _images
                ..clear()
                ..addAll(next);
            }),
          ),
          onRemove: (image) => setState(() => _images.remove(image)),
        ),
        const SizedBox(height: 12),
        const _ReportDeviceCard(),
        const SizedBox(height: 16),
        const RateAppTile(),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class SettingsReportRouteFormScreen extends ConsumerStatefulWidget {
  const SettingsReportRouteFormScreen({
    this.prefilledRouteId,
    this.prefilledRouteName,
    super.key,
  });

  final String? prefilledRouteId;
  final String? prefilledRouteName;

  @override
  ConsumerState<SettingsReportRouteFormScreen> createState() =>
      _SettingsReportRouteFormScreenState();
}

class _SettingsReportRouteFormScreenState
    extends ConsumerState<SettingsReportRouteFormScreen> {
  final _description = TextEditingController();
  final _images = <XFile>[];
  String? _selectedRouteId;
  String? _selectedRouteTitle;
  var _routePickerOpen = false;
  String? _problemType;
  var _problemTypeOpen = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.prefilledRouteId;
    _selectedRouteTitle = widget.prefilledRouteName;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _description.text.trim();
    final routeId = _selectedRouteId;
    if (routeId == null) {
      showAppNotice(context, 'Выберите маршрут');
      return;
    }
    if (_problemType == null) {
      showAppNotice(context, 'Выберите тип проблемы');
      return;
    }
    if (body.isEmpty) {
      showAppNotice(context, 'Опишите проблему');
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final routeName = _selectedRouteTitle ?? routeId;
    try {
      final repo = ref.read(supportRepositoryProvider);
      final ticket = await repo.createTicket(
        kind: 'route_error',
        subject: 'Ошибка на маршруте: $routeName ($_problemType)',
        body: body,
        routeId: routeId,
      );
      await uploadReportAttachments(repo, ticketId: ticket.id, images: _images);
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRouteNames.settingsThanks));
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      showAppNotice(context, error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final executions = ref
        .watch(routeExecutionHistoryProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <RouteExecution>[],
        );
    final options = _reportRouteOptions(
      executions,
      prefilledRouteId: widget.prefilledRouteId,
      prefilledRouteName: widget.prefilledRouteName,
    );
    final selectedIndex = _selectedRouteId == null
        ? null
        : options.indexWhere((option) => option.id == _selectedRouteId);
    final selected = (selectedIndex == null || selectedIndex < 0)
        ? null
        : options[selectedIndex];
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
              _ReportRoutePicker(
                selectedTitle: selected?.title,
                selectedSubtitle: selected?.subtitle,
                open: _routePickerOpen,
                routes: [
                  for (final option in options) (option.title, option.subtitle),
                ],
                onToggle: () => setState(() {
                  _routePickerOpen = !_routePickerOpen;
                  if (_routePickerOpen) {
                    _problemTypeOpen = false;
                  }
                }),
                onSelect: (index) => setState(() {
                  _selectedRouteId = options[index].id;
                  _selectedRouteTitle = options[index].title;
                  _routePickerOpen = false;
                }),
              ),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Пока нет маршрутов для выбора — пройдите маршрут или '
                    'откройте форму из его карточки.',
                    style: AppTypography.settingsRowSubtitle.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReportOptionPicker(
          label: 'Тип проблемы:',
          value: _problemType,
          placeholder: 'Выберите тип проблемы',
          open: _problemTypeOpen,
          options: _routeProblemTypes,
          onToggle: () => setState(() {
            _problemTypeOpen = !_problemTypeOpen;
            if (_problemTypeOpen) {
              _routePickerOpen = false;
            }
          }),
          onSelect: (value) => setState(() {
            _problemType = value;
            _problemTypeOpen = false;
          }),
        ),
        const SizedBox(height: 12),
        _ReportDescriptionCard(controller: _description),
        const SizedBox(height: 12),
        _ReportScreenshotCard(
          isPhoto: true,
          images: _images,
          busy: _busy,
          onPick: () => pickReportImages(
            context,
            images: _images,
            onChanged: (next) => setState(() {
              _images
                ..clear()
                ..addAll(next);
            }),
          ),
          onRemove: (image) => setState(() => _images.remove(image)),
        ),
        const SizedBox(height: 12),
        const _ReportDeviceCard(),
        const SizedBox(height: 16),
        const RateAppTile(),
        const SizedBox(height: SettingsMetrics.rowGap),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class _ReportOptionPicker extends StatelessWidget {
  const _ReportOptionPicker({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.open,
    required this.options,
    required this.onToggle,
    required this.onSelect,
  });

  final String label;
  final String? value;
  final String placeholder;
  final bool open;
  final List<String> options;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SettingsFormCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.settingsRowTitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value ?? placeholder,
                          style: value == null
                              ? AppTypography.settingsRowSubtitle
                              : AppTypography.settingsRowSubtitle.copyWith(
                                  color: AppColors.settingsInk,
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            for (final option in options) ...[
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              InkWell(
                onTap: () => onSelect(option),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Text(
                      option,
                      style: AppTypography.settingsRowSubtitle.copyWith(
                        color: option == value
                            ? AppColors.settingsInk
                            : AppColors.secondaryInk,
                        fontWeight: option == value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _ReportRoutePicker extends StatelessWidget {
  const _ReportRoutePicker({
    required this.selectedTitle,
    required this.selectedSubtitle,
    required this.open,
    required this.routes,
    required this.onToggle,
    required this.onSelect,
  });

  final String? selectedTitle;
  final String? selectedSubtitle;
  final bool open;
  final List<(String, String)> routes;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedTitle != null;
    // Keep a stable rounded rect while open/selected so the dropdown does not
    // morph from a capsule pill into a tall stadium shape.
    final radius = (open || selected) ? 12.0 : AppRadii.capsule;
    return Material(
      color: selected ? const Color(0xFFF2F2F2) : SettingsColors.fieldFill,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: selected ? 56 : 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (selected)
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
                      child: selected
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedTitle!,
                                  style: AppTypography.settingsRowTitle
                                      .copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  selectedSubtitle!,
                                  style: AppTypography.settingsRowSubtitle
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            )
                          : const Text(
                              'Искать маршрут',
                              style: AppTypography.settingsRowSubtitle,
                            ),
                    ),
                    Icon(
                      open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            for (var i = 0; i < routes.length; i++) ...[
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              InkWell(
                onTap: () => onSelect(i),
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routes[i].$1,
                                style: AppTypography.settingsRowTitle.copyWith(
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                routes[i].$2,
                                style: AppTypography.settingsRowSubtitle
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
    );
  }
}

class _ReportDescriptionCard extends StatelessWidget {
  const _ReportDescriptionCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Описание:',
            style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
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
                borderSide: const BorderSide(color: SettingsColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SettingsColors.hairline),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

const _reportMaxImages = 3;
const _reportMaxImageBytes = 10 * 1024 * 1024;

/// Shared picker for both report screens — enforces the same per-file size
/// cap and total-count cap the backend enforces (3 attachments/ticket).
Future<void> pickReportImages(
  BuildContext context, {
  required List<XFile> images,
  required ValueChanged<List<XFile>> onChanged,
}) async {
  final available = _reportMaxImages - images.length;
  if (available <= 0) {
    return;
  }
  try {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 86,
      limit: available,
      requestFullMetadata: false,
    );
    final accepted = <XFile>[];
    for (final image in picked) {
      if (await image.length() <= _reportMaxImageBytes) {
        accepted.add(image);
      }
    }
    onChanged([...images, ...accepted.take(available)]);
    if (accepted.length != picked.length && context.mounted) {
      showAppNotice(context, 'Фото больше 10 МБ не добавлены');
    }
  } on Object {
    if (context.mounted) {
      showAppNotice(context, 'Не удалось выбрать фотографии');
    }
  }
}

/// Uploads every picked photo to the just-created ticket. Attachment
/// failures are swallowed — the ticket itself was already created
/// successfully, and a missing photo isn't worth blocking the report on.
Future<void> uploadReportAttachments(
  SupportRepository repo, {
  required String ticketId,
  required List<XFile> images,
}) async {
  for (final image in images) {
    try {
      await repo.uploadAttachment(ticketId: ticketId, filePath: image.path);
    } on Object {
      // Best-effort: the report itself already succeeded.
    }
  }
}

class _ReportScreenshotCard extends StatelessWidget {
  const _ReportScreenshotCard({
    required this.isPhoto,
    required this.images,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final bool isPhoto;
  final List<XFile> images;
  final bool busy;
  final VoidCallback onPick;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final noun = isPhoto ? 'Фото' : 'Скриншот';
    final nounLower = isPhoto ? 'фото' : 'скриншот';
    return SettingsFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$noun проблемы (рекомендуется):',
            style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = images[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(image.path),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: busy ? null : () => onRemove(image),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (images.length < _reportMaxImages)
            SettingsDashedUpload(
              label: 'Добавить $nounLower',
              subtitle: 'Это поможет лучше понять проблему',
              onTap: busy ? () {} : onPick,
            ),
        ],
      ),
    );
  }
}

class _ReportDeviceCard extends ConsumerWidget {
  const _ReportDeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelAsync = ref.watch(deviceAndVersionLabelProvider);
    return SettingsFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Устройство и версия (автоматически)',
            style: AppTypography.settingsRowTitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            labelAsync.valueOrNull ?? 'Определяем устройство…',
            style: AppTypography.settingsRowSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
