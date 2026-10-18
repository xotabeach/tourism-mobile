import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tourism_mobile/features/companions/presentation/flat/mountain_route.dart';
import 'package:tourism_mobile/features/companions/presentation/group_design.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 44,
        surfaceTintColor: Colors.transparent,
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
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupTitle('Совместный маршрут:'),
        const SizedBox(height: 12),
        _routeCard(group),
      ],
    );
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
        GroupOutlineButton(
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
          kind: member.beanKind,
          outfit: member.beanOutfit,
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
    GroupDarkButton(
      label: 'Пойду',
      onPressed: _busy
          ? null
          : () => _act(() => _repo.respond(group.id, accept: true)),
    ),
    const SizedBox(height: 8),
    GroupOutlineButton(
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

  BeanKind _kindOf(String userId, String? kind) =>
      BeanKind.fromSlug(kind) ?? BeanKind.forUser(userId);

  void _openProfile(String userId) => unawaited(
    context.pushNamed(
      AppRouteNames.userProfileStandalone,
      pathParameters: {'userId': userId},
    ),
  );

  void _openRoute(CompanionGroup group) => unawaited(
    context.pushNamed(
      AppRouteNames.routeDetailsStandalone,
      pathParameters: {'id': group.routeId},
    ),
  );

  Widget _routeCard(CompanionGroup group) => GroupRouteCard(
    routeId: group.routeId,
    name: group.routeName,
    coverUrl: group.routeCoverUrl,
    onTap: () => _openRoute(group),
  );

  /// The organizer's choice on someone in the camp: their profile, or out.
  Future<void> _memberMenu(CompanionGroup group, CompanionMember member) async {
    if (!group.isOrganizer || member.isOrganizer) {
      _openProfile(member.userId);
      return;
    }
    final invited = member.state == CompanionMemberState.invited;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Открыть профиль'),
              onTap: () => Navigator.of(sheet).pop('profile'),
            ),
            ListTile(
              title: Text(
                invited ? 'Отозвать приглашение' : 'Убрать из группы',
                style: const TextStyle(color: GroupDesign.danger),
              ),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'profile') _openProfile(member.userId);
    if (choice == 'remove') {
      await _act(() => _repo.removeMember(group.id, member.userId));
    }
  }

  /// Gathering, as on the designer's lobby (FRONTEND-88).
  List<Widget> _gathering(CompanionGroup group, Widget header) {
    final me = group.memberOf(_me ?? '');
    final ready = me?.ready ?? false;
    final joined = group.joined;
    final readyCount = joined.where((m) => m.ready || m.isOrganizer).length;
    return [
      const GroupTitle('Совместный маршрут:'),
      const SizedBox(height: 12),
      _routeCard(group),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) => CampfireScene(
          height: constraints.maxWidth * 228 / 343,
          labelsAbove: true,
          members: _camp(group),
          departing: _departing,
          // Only a ready phone starts its run on its own (spec 11b D12);
          // the rest stay in the group as «не стартовал».
          onDeparted: () {
            if (group.isOrganizer || (me?.ready ?? false)) {
              _openRun();
            } else {
              unawaited(_refresh());
            }
          },
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'У костра: ${joined.length}/${group.maxMembers} • Готовы: $readyCount',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.rubik,
          fontSize: 13,
          color: AppColors.secondaryInk,
        ),
      ),
      const SizedBox(height: 17),
      if (group.isOrganizer) ...[
        GroupDarkButton(
          label: 'Выйти на тропу',
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
        GroupDarkButton(
          label: ready ? 'Не готов' : 'Готов',
          onPressed: _busy
              ? null
              : () => _act(() => _repo.setReady(group.id, ready: !ready)),
        ),
      const SizedBox(height: 16),
      if (group.joinCode != null)
        GroupCodeBlock(code: group.joinCode!, routeName: group.routeName),
      if (group.isOrganizer) ...[
        const SizedBox(height: 12),
        GroupOutlineButton(
          label: 'Позвать друзей',
          onPressed: () => showInviteSheet(
            context,
            group: group,
            onChanged: (updated) => setState(() => _group = updated),
          ),
        ),
      ],
      if (group.isOrganizer && group.requests.isNotEmpty) ...[
        const SizedBox(height: 24),
        const GroupTitle('Просятся в группу:'),
        const SizedBox(height: 8),
        for (final member in group.requests)
          GroupMemberRow(
            kind: _kindOf(member.userId, member.beanKind),
            name: member.displayName,
            subtitle: member.rankTitle ?? 'Хочет пойти с вами',
            onTap: () => _openProfile(member.userId),
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
                  icon: const Icon(Icons.cancel, color: GroupDesign.danger),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: 24),
      const GroupTitle('Попутчики:'),
      const SizedBox(height: 8),
      for (final member in [...joined, ...group.invited])
        GroupMemberRow(
          kind: _kindOf(member.userId, member.beanKind),
          name: member.displayName,
          organizer: member.isOrganizer,
          faded: member.state == CompanionMemberState.invited,
          subtitle: member.state == CompanionMemberState.invited
              ? 'Ждём ответа'
              : member.rankTitle ?? 'Путник',
          onTap: () => unawaited(_memberMenu(group, member)),
        ),
      const SizedBox(height: 20),
      if (group.isOrganizer)
        GroupDangerButton(
          label: 'Отменить группу',
          onPressed: _busy ? null : () => _act(() => _repo.cancel(group.id)),
        )
      else
        GroupDangerButton(
          label: 'Покинуть группу',
          onPressed: _busy || _me == null
              ? null
              : () => _act(() => _repo.removeMember(group.id, _me!)),
        ),
    ];
  }

  /// Where a member stands on the mountain, as a stop index from 0.
  double _mountainAt(CompanionMemberProgress member, int stops) {
    if (member.reached || member.status == CompanionRunStatus.finished) {
      return (stops - 1).toDouble();
    }
    if (member.lastPosition <= 0) return 0;
    final at = member.lastPosition - 1;
    // Walking on: a little way up toward the next stop.
    return member.status == CompanionRunStatus.walking && at < stops - 1
        ? at + 0.4
        : at.toDouble();
  }

  String _whereIs(CompanionMemberProgress member, CompanionProgress progress) {
    if (member.status == CompanionRunStatus.notStarted &&
        member.lastPosition == 0) {
      return 'Ещё не вышел';
    }
    final stop = progress.stops
        .where((s) => s.position == member.lastPosition)
        .firstOrNull;
    if (stop == null) return 'На старте';
    final meters = stop.distanceFromStartMeters;
    return [
      if (meters == 0)
        'Старт'
      else if (meters != null)
        '${formatDistance(meters)} от старта',
      stop.placeName,
    ].join(' • ');
  }

  /// On the way, as on the designer's mountain (FRONTEND-89).
  List<Widget> _onTheWay(CompanionGroup group, Widget header) {
    final progress = _progress;
    final me = group.memberOf(_me ?? '');
    final settled = group.status == CompanionGroupStatus.settled;
    final mine = progress?.members.where((m) => m.userId == _me).firstOrNull;
    final started = me?.started ?? false;
    String? walked;
    String? toNext;
    if (progress != null && mine != null && mine.startedAt != null) {
      final end = mine.finishedAt ?? DateTime.now();
      walked = '${end.difference(mine.startedAt!).inMinutes} мин.';
      final here = progress.stops
          .where((s) => s.position == mine.lastPosition)
          .firstOrNull;
      final next = progress.stops
          .where((s) => s.position > mine.lastPosition)
          .firstOrNull;
      final from = here?.distanceFromStartMeters ?? 0;
      final to = next?.distanceFromStartMeters;
      if (to != null && to >= from) toNext = formatDistance(to - from);
    }
    return [
      GroupTitle(settled ? 'Маршрут пройден:' : 'Группа в пути:'),
      const SizedBox(height: 12),
      _routeCard(group),
      const SizedBox(height: 16),
      if (progress == null)
        const AppShimmer(
          child: AspectRatio(
            aspectRatio: MountainRoute.aspect,
            child: AppSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 16,
            ),
          ),
        )
      else ...[
        MountainRoute(
          stops: progress.stops.length,
          walkers: [
            for (final member in progress.members)
              MountainWalker(
                kind: _kindOf(member.userId, member.beanKind),
                at: _mountainAt(member, progress.stops.length),
              ),
          ],
        ),
        if (started && walked != null) ...[
          const SizedBox(height: 14),
          GroupStatRow(
            icon: Icons.alarm_outlined,
            label: 'Всего в пути:',
            value: walked,
          ),
          if (toNext != null && !settled) ...[
            const SizedBox(height: 6),
            GroupStatRow(
              icon: Icons.near_me_outlined,
              label: 'До след. точки',
              value: toNext,
            ),
          ],
        ],
        if (!settled && me != null) ...[
          const SizedBox(height: 16),
          GroupDarkButton(
            label: started ? 'Перейти к маршруту' : 'Начать прохождение',
            onPressed: _openRun,
          ),
        ],
        const SizedBox(height: 24),
        const GroupTitle('Участники маршрута:'),
        const SizedBox(height: 8),
        for (final member in progress.members)
          GroupMemberRow(
            kind: _kindOf(member.userId, member.beanKind),
            name: member.displayName,
            subtitle: _whereIs(member, progress),
            onTap: () => _openProfile(member.userId),
          ),
        if (settled) ...[
          const SizedBox(height: 24),
          const GroupTitle('Открытка группы:'),
          const SizedBox(height: 8),
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
                () =>
                    value ? _hiddenOnCard.remove(_me) : _hiddenOnCard.add(_me!),
              ),
            ),
          GroupOutlineButton(
            label: 'Поделиться открыткой',
            onPressed: () => unawaited(_shareCard()),
          ),
        ],
        if (!settled && me?.state == CompanionMemberState.joined) ...[
          const SizedBox(height: 20),
          GroupDangerButton(
            label: 'Сойти с дистанции',
            onPressed: _busy ? null : () => unawaited(_leaveOnTheWay(group)),
          ),
        ],
      ],
    ];
  }
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
