import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/campfire_scene.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/group_postcard.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/rope_view.dart';
import 'package:tourism_mobile/features/companions/presentation/group_qr.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// One group of companions from invitation to the finish (spec 11b).
///
/// Gathering is a camp by the fire; after the start the screen shows the
/// «связка» and the table, at the end the group's card. While open, it
/// refreshes itself: often around the fire, every half a minute on the way.
class CompanionGroupScreen extends ConsumerStatefulWidget {
  const CompanionGroupScreen({required this.groupId, super.key});

  final String groupId;

  static const gatheringPoll = Duration(seconds: 5);
  static const walkingPoll = Duration(seconds: 30);

  @override
  ConsumerState<CompanionGroupScreen> createState() =>
      _CompanionGroupScreenState();
}

class _CompanionGroupScreenState extends ConsumerState<CompanionGroupScreen> {
  CompanionGroup? _group;
  CompanionProgress? _progress;
  Object? _error;
  var _busy = false;
  var _departing = false;
  Timer? _poll;
  final _hiddenOnCard = <String>{};
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  CompanionsRepository get _repo => ref.read(companionsRepositoryProvider);

  Future<void> _refresh() async {
    try {
      final group = await _repo.get(widget.groupId);
      CompanionProgress? progress;
      if (group.isInside &&
          (group.status == CompanionGroupStatus.started ||
              group.status == CompanionGroupStatus.settled)) {
        progress = await _repo.progress(widget.groupId);
      }
      if (!mounted) return;
      final wasGathering = _group?.status == CompanionGroupStatus.gathering;
      if (_group != null &&
          (_group!.status != group.status ||
              _group!.myState != group.myState)) {
        ref.invalidate(myCompanionGroupsProvider);
      }
      setState(() {
        _group = group;
        _progress = progress ?? _progress;
        _error = null;
      });
      // Someone else gave the start: the camp walks off, then the run opens.
      if (wasGathering &&
          group.status == CompanionGroupStatus.started &&
          !_departing) {
        setState(() => _departing = true);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
    _schedule();
  }

  void _schedule() {
    _poll?.cancel();
    final status = _group?.status;
    if (status == null || !status.isLive) return;
    _poll = Timer(
      status == CompanionGroupStatus.gathering
          ? CompanionGroupScreen.gatheringPoll
          : CompanionGroupScreen.walkingPoll,
      () => unawaited(_refresh()),
    );
  }

  Future<void> _act(
    Future<CompanionGroup?> Function() action, {
    String? done,
  }) async {
    setState(() => _busy = true);
    try {
      final group = await action();
      // The home card and «Мои группы» follow what was done here.
      ref.invalidate(myCompanionGroupsProvider);
      if (!mounted) return;
      if (group == null) {
        unawaited(Navigator.of(context).maybePop());
        return;
      }
      setState(() => _group = group);
      if (done != null) showAppNotice(context, done);
    } on Object catch (error) {
      if (mounted) await showCompanionError(context, ref, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    unawaited(_refresh());
  }

  /// Leaving a group on the way (FRONTEND-80): asked first, as there is no
  /// coming back without a new invitation. The organizer too, since a group
  /// on the way cannot be cancelled.
  Future<void> _leaveOnTheWay(CompanionGroup group) async {
    final me = _me;
    if (me == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Выйти из группы?'),
        content: const Text(
          'Попутчики увидят, что вы вышли. Ваше прохождение маршрута не '
          'прервётся, но идти вы будете уже без группы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Остаться'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _act(() => _repo.removeMember(group.id, me));
  }

  Future<void> _start() async {
    await _act(() => _repo.start(widget.groupId));
    if (mounted && _group?.status == CompanionGroupStatus.started) {
      setState(() => _departing = true);
    }
  }

  void _openRun() {
    final group = _group;
    if (group == null) return;
    unawaited(
      context.pushNamed(
        AppRouteNames.routeExecution,
        pathParameters: {'id': group.routeId},
        queryParameters: {'group': group.id},
      ),
    );
  }

  Future<void> _report() async {
    final reason = await showInviteReportSheet(context);
    if (reason == null || !mounted) return;
    try {
      await _repo.report(widget.groupId, reason: reason);
      if (!mounted) return;
      showAppNotice(context, 'Жалоба отправлена, приглашение отклонено');
      unawaited(Navigator.of(context).maybePop());
    } on Object catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          companionErrorText(error),
          kind: AppNoticeKind.error,
        );
      }
    }
  }

  Future<void> _shareCard() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'krymtrip-group.png',
          ),
        ],
        text: 'Прошли вместе: «${_group?.routeName ?? ''}». КрымТрип',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Пройти вместе',
          style: TextStyle(
            fontFamily: AppFonts.rubik,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: group == null
          ? Center(
              child: _error == null
                  ? const _GroupSkeleton()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            companionErrorText(_error!),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: _body(group),
              ),
            ),
    );
  }

  String? get _me => ref.read(myUserIdProvider);

  List<Widget> _body(CompanionGroup group) {
    final header = _RouteHeader(group: group);
    if (group.status == CompanionGroupStatus.cancelled) {
      return [
        header,
        const SizedBox(height: 16),
        _Note(
          text: group.cancelReason == 'route_unavailable'
              ? 'Маршрут сняли с публикации, поэтому группа отменена.'
              : 'Организатор отменил совместный маршрут.',
        ),
      ];
    }
    if (group.isInvitation) return _invitation(group, header);
    if (group.isRequest) {
      return [
        header,
        const SizedBox(height: 16),
        CampfireScene(members: _camp(group)),
        const SizedBox(height: 16),
        const _Note(text: 'Ждём, когда организатор впустит вас в группу.'),
        const SizedBox(height: 12),
        _SecondaryButton(
          label: 'Передумал',
          onPressed: _busy || _me == null
              ? null
              : () => _act(() => _repo.removeMember(group.id, _me!)),
        ),
      ];
    }
    return switch (group.status) {
      CompanionGroupStatus.gathering => _gathering(group, header),
      _ => _onTheWay(group, header),
    };
  }

  List<CampMember> _camp(CompanionGroup group) => [
    for (final member in group.members)
      if (member.state == CompanionMemberState.joined ||
          member.state == CompanionMemberState.invited ||
          member.state == CompanionMemberState.requested)
        CampMember(
          userId: member.userId,
          name: member.displayName,
          ready: member.ready || member.isOrganizer && _departing,
          organizer: member.isOrganizer,
          waiting: member.state != CompanionMemberState.joined,
          hat: member.beanHat,
        ),
  ];

  List<Widget> _invitation(CompanionGroup group, Widget header) => [
    header,
    const SizedBox(height: 16),
    CampfireScene(members: _camp(group)),
    const SizedBox(height: 16),
    _Note(
      text:
          '${group.organizerName} зовёт вас пройти этот маршрут вместе. '
          'Каждый отмечает точки сам, а в группе видно, кто где.',
    ),
    const SizedBox(height: 16),
    _PrimaryButton(
      label: 'Пойду',
      onPressed: _busy
          ? null
          : () => _act(() => _repo.respond(group.id, accept: true)),
    ),
    const SizedBox(height: 8),
    _SecondaryButton(
      label: 'Не пойду',
      onPressed: _busy
          ? null
          : () async {
              await _act(() => _repo.respond(group.id, accept: false));
              if (mounted) unawaited(Navigator.of(context).maybePop());
            },
    ),
    TextButton(
      onPressed: _report,
      child: const Text(
        'Пожаловаться',
        style: TextStyle(color: AppColors.secondaryInk),
      ),
    ),
  ];

  List<Widget> _gathering(CompanionGroup group, Widget header) {
    final me = group.memberOf(_me ?? '');
    final ready = me?.ready ?? false;
    final joined = group.joined;
    final readyCount = joined.where((m) => m.ready || m.isOrganizer).length;
    return [
      header,
      const SizedBox(height: 16),
      CampfireScene(
        members: _camp(group),
        departing: _departing,
        // Only a ready phone starts its run on its own (spec 11b D12); the
        // rest stay in the group as «не стартовал» and may start later.
        onDeparted: () {
          if (group.isOrganizer || (me?.ready ?? false)) {
            _openRun();
          } else {
            unawaited(_refresh());
          }
        },
      ),
      const SizedBox(height: 10),
      Text(
        'У костра ${joined.length} из ${group.maxMembers} · готовы $readyCount',
        textAlign: TextAlign.center,
        style: AppTypography.settingsRowSubtitle,
      ),
      const SizedBox(height: 16),
      if (group.isOrganizer) ...[
        _PrimaryButton(
          label: 'Старт! Выходим на тропу',
          onPressed: _busy || joined.length < 2 || _departing ? null : _start,
        ),
        if (joined.length < 2)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Позовите хотя бы одного попутчика',
              textAlign: TextAlign.center,
              style: AppTypography.settingsRowSubtitle,
            ),
          ),
      ] else
        _PrimaryButton(
          label: ready ? 'Я готов ✓' : 'Я готов',
          tone: ready ? FlatPalette.trail : null,
          onPressed: _busy
              ? null
              : () => _act(() => _repo.setReady(group.id, ready: !ready)),
        ),
      const SizedBox(height: 20),
      if (group.joinCode != null) _CodeCard(code: group.joinCode!),
      if (group.isOrganizer) ...[
        const SizedBox(height: 12),
        _SecondaryButton(
          label: 'Позвать друзей',
          onPressed: () => showInviteSheet(
            context,
            group: group,
            onChanged: (updated) => setState(() => _group = updated),
          ),
        ),
      ],
      if (group.isOrganizer && group.requests.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _SectionTitle('Просятся в группу'),
        for (final member in group.requests)
          _MemberRow(
            member: member,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Впустить',
                  onPressed: () => _act(
                    () => _repo.answerRequest(
                      group.id,
                      member.userId,
                      approve: true,
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle,
                    color: FlatPalette.trail,
                  ),
                ),
                IconButton(
                  tooltip: 'Не впускать',
                  onPressed: () => _act(
                    () => _repo.answerRequest(
                      group.id,
                      member.userId,
                      approve: false,
                    ),
                  ),
                  icon: const Icon(Icons.cancel, color: Color(0xFFE5484D)),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: 20),
      const _SectionTitle('Кто идёт'),
      for (final member in [...joined, ...group.invited])
        _MemberRow(
          member: member,
          subtitle: member.state == CompanionMemberState.invited
              ? 'Ждём ответа'
              : member.isOrganizer
              ? 'Организатор'
              : member.ready
              ? 'Готов'
              : 'Собирается',
          trailing: group.isOrganizer && !member.isOrganizer
              ? IconButton(
                  tooltip: member.state == CompanionMemberState.invited
                      ? 'Отозвать приглашение'
                      : 'Убрать из группы',
                  onPressed: () =>
                      _act(() => _repo.removeMember(group.id, member.userId)),
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
        ),
      const SizedBox(height: 20),
      if (group.isOrganizer)
        _SecondaryButton(
          label: 'Отменить группу',
          danger: true,
          onPressed: _busy
              ? null
              : () async {
                  await _act(() => _repo.cancel(group.id));
                },
        )
      else
        _SecondaryButton(
          label: 'Выйти из группы',
          danger: true,
          onPressed: _busy || _me == null
              ? null
              : () => _act(() => _repo.removeMember(group.id, _me!)),
        ),
    ];
  }

  List<Widget> _onTheWay(CompanionGroup group, Widget header) {
    final progress = _progress;
    final me = group.memberOf(_me ?? '');
    final settled = group.status == CompanionGroupStatus.settled;
    return [
      header,
      const SizedBox(height: 16),
      if (progress == null)
        const AppShimmer(
          child: AppSkeleton(
            width: double.infinity,
            height: 170,
            borderRadius: 22,
          ),
        )
      else ...[
        RopeView(progress: progress),
        const SizedBox(height: 16),
        if (!settled && me != null && !me.started) ...[
          _PrimaryButton(label: 'Начать своё прохождение', onPressed: _openRun),
          const SizedBox(height: 16),
        ],
        const _SectionTitle('Кто где'),
        for (final member in progress.members)
          _ProgressRow(member: member, stops: progress.stops.length),
        if (!progress.leaderboardHidden &&
            progress.stops.any((stop) => stop.firstUserId != null)) ...[
          const SizedBox(height: 20),
          const _SectionTitle('Кто первым дошёл'),
          for (final stop in progress.stops)
            if (stop.firstUserId != null)
              _FirstRow(
                place: '${stop.position}. ${stop.placeName}',
                userId: stop.firstUserId!,
                name: progress.members
                    .firstWhere(
                      (m) => m.userId == stop.firstUserId,
                      orElse: () => CompanionMemberProgress(
                        userId: stop.firstUserId!,
                        displayName: '',
                        status: CompanionRunStatus.notStarted,
                      ),
                    )
                    .displayName,
              ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Отметки без сети в зачёт первенства не идут. Очков за место '
              'нет, только слава.',
              style: AppTypography.settingsRowSubtitle,
            ),
          ),
        ] else if (progress.leaderboardHidden) ...[
          const SizedBox(height: 16),
          const _Note(
            text:
                'На горном маршруте не соревнуемся: идите в своём темпе и '
                'держитесь вместе.',
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('Открытка группы'),
        RepaintBoundary(
          key: _cardKey,
          child: GroupPostcard(
            routeName: group.routeName,
            progress: progress,
            hiddenUserIds: _hiddenOnCard,
          ),
        ),
        const SizedBox(height: 10),
        if (_me != null)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: !_hiddenOnCard.contains(_me),
            title: const Text('Я на открытке'),
            onChanged: (value) => setState(
              () => value ? _hiddenOnCard.remove(_me) : _hiddenOnCard.add(_me!),
            ),
          ),
        _SecondaryButton(
          label: settled ? 'Поделиться открыткой' : 'Поделиться: мы ещё идём',
          onPressed: () => unawaited(_shareCard()),
        ),
        if (!settled && me?.state == CompanionMemberState.joined) ...[
          const SizedBox(height: 10),
          _SecondaryButton(
            label: 'Выйти из группы',
            danger: true,
            onPressed: _busy ? null : () => unawaited(_leaveOnTheWay(group)),
          ),
        ],
      ],
    ];
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.group});

  final CompanionGroup group;

  @override
  Widget build(BuildContext context) {
    final status = switch (group.status) {
      CompanionGroupStatus.gathering => 'Собираемся у костра',
      CompanionGroupStatus.started => 'Группа в пути',
      CompanionGroupStatus.settled => 'Итог зафиксирован',
      CompanionGroupStatus.cancelled => 'Группа отменена',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FlatPalette.flameOuter,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          group.routeName,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryInk,
          ),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FlatPalette.paper,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Код группы',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  color: Color(0xFF6B6B7B),
                ),
              ),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: FlatPalette.ink,
                ),
              ),
              const Text(
                'Покажите код или QR тому, кто рядом',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 12,
                  color: Color(0xFF6B6B7B),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          key: const ValueKey('group-qr'),
          onTap: () => unawaited(showGroupQrSheet(context, code)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GroupQrImage(code: code, size: 64),
          ),
        ),
        IconButton(
          tooltip: 'Скопировать код',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showAppNotice(context, 'Код скопирован');
          },
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.subtitle, this.trailing});

  final CompanionMember member;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        BeanFace(userId: member.userId),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.displayName, style: AppTypography.settingsRowTitle),
              if (subtitle != null)
                Text(subtitle!, style: AppTypography.settingsRowSubtitle),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.member, required this.stops});

  final CompanionMemberProgress member;
  final int stops;

  @override
  Widget build(BuildContext context) {
    final offline = member.marks.any((mark) => mark.offline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          BeanFace(userId: member.userId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: AppTypography.settingsRowTitle),
                Text(
                  [
                    member.status.label,
                    if (member.status != CompanionRunStatus.notStarted)
                      'точка ${member.lastPosition} из $stops',
                    if (member.joinedLate) 'присоединился позже',
                    if (offline) 'есть отметки без сети',
                  ].join(' · '),
                  style: AppTypography.settingsRowSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstRow extends StatelessWidget {
  const _FirstRow({
    required this.place,
    required this.userId,
    required this.name,
  });

  final String place;
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.emoji_events, size: 20, color: FlatPalette.beanFor(userId)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.settingsRowSubtitle,
          ),
        ),
        Text(name, style: AppTypography.settingsRowTitle),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryInk,
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FlatPalette.paper,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 15,
        height: 1.35,
        color: FlatPalette.ink,
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed, this.tone});

  final String label;
  final VoidCallback? onPressed;
  final Color? tone;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: tone ?? FlatPalette.flameOuter,
      foregroundColor: FlatPalette.white,
      minimumSize: const Size.fromHeight(54),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Text(label),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: danger ? const Color(0xFFE5484D) : AppColors.primaryInk,
      minimumSize: const Size.fromHeight(50),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: danger ? const Color(0x55E5484D) : const Color(0xFFD7D7D7),
      ),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    child: Text(label),
  );
}

/// The camp, the button and the code card, in their places while loading.
class _GroupSkeleton extends StatelessWidget {
  const _GroupSkeleton();

  @override
  Widget build(BuildContext context) => const AppShimmer(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 140, height: 13, borderRadius: 6),
          SizedBox(height: 8),
          AppSkeleton(width: 240, height: 24, borderRadius: 8),
          SizedBox(height: 16),
          AppSkeleton(width: double.infinity, height: 300, borderRadius: 24),
          SizedBox(height: 16),
          AppSkeleton(width: double.infinity, height: 54, borderRadius: 27),
          SizedBox(height: 20),
          AppSkeleton(width: double.infinity, height: 90, borderRadius: 20),
          Spacer(),
        ],
      ),
    ),
  );
}
