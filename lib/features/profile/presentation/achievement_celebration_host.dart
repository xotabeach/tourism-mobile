import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/startup/startup_config.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/achievements_repository.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/settings/application/notifications_inbox_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

List<List<ProfileAchievement>> celebrationBatches(
  List<ProfileAchievement> items,
) => items.length > 3
    ? [items]
    : [
        for (final item in items) [item],
      ];

/// Shared with push navigation so a card opened from push is not toasted too.
final openedAchievementIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(sessionProvider.select((s) => s.userId));
  return {};
});

class AchievementCelebrationHost extends ConsumerStatefulWidget {
  const AchievementCelebrationHost({super.key});
  @override
  ConsumerState<AchievementCelebrationHost> createState() =>
      _AchievementCelebrationHostState();
}

class _AchievementCelebrationHostState
    extends ConsumerState<AchievementCelebrationHost>
    with WidgetsBindingObserver {
  final _seen = <String>{};
  final _pendingAck = <String>{};
  final _queue = <List<ProfileAchievement>>[];
  List<ProfileAchievement>? _current;
  Timer? _timer;
  bool _loading = false;
  bool _currentShown = false;
  bool _resumed = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed) {
      _timer?.cancel();
      if (_current != null && !_currentShown) _queue.insert(0, _current!);
      if (mounted) setState(() => _current = null);
    }
    if (_resumed) {
      _next();
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (!mounted ||
        _loading ||
        !_resumed ||
        ref.read(startupGateActiveProvider)) {
      return;
    }
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) return;
    final generation = _generation;
    _loading = true;
    try {
      final repo = ref.read(achievementsRepositoryProvider);
      if (_pendingAck.isNotEmpty) {
        final ids = _pendingAck.toList();
        await repo.celebrate(ids);
        if (!mounted || generation != _generation) return;
        _pendingAck.removeAll(ids);
      }
      final items = await repo.list(uncelebrated: true);
      if (!mounted || generation != _generation) return;
      final opened = ref.read(openedAchievementIdsProvider);
      final directId = ref
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .queryParameters['achievementId'];
      final fresh = items
          .where(
            (item) =>
                !_seen.contains(item.id) &&
                !opened.contains(item.id) &&
                item.id != directId,
          )
          .toList();
      if (fresh.isEmpty) return;
      final userId = session.userId;
      if (userId != null) ref.invalidate(userAchievementsProvider(userId));
      _seen.addAll(fresh.map((item) => item.id));
      _queue.addAll(celebrationBatches(fresh));
      _next();
    } on Object {
      // Inbox polling/resume retries; never block the action that earned it.
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  void _next() {
    if (!mounted || !_resumed || _current != null || _queue.isEmpty) return;
    final opened = ref.read(openedAchievementIdsProvider);
    final batch = _queue
        .removeAt(0)
        .where((item) => !opened.contains(item.id))
        .toList();
    if (batch.isEmpty) {
      _next();
      return;
    }
    _currentShown = false;
    setState(() => _current = batch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _current != batch || !_resumed) return;
      _currentShown = true;
      final ids = batch.map((item) => item.id).toList();
      _pendingAck.addAll(ids);
      final generation = _generation;
      unawaited(
        ref
            .read(achievementsRepositoryProvider)
            .celebrate(ids)
            .then((_) {
              if (mounted && generation == _generation) {
                _pendingAck.removeAll(ids);
              }
            })
            .catchError((Object _) {}),
      );
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), _dismiss);
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _current = null);
    _next();
  }

  void _open() {
    final batch = _current;
    if (batch == null) return;
    _dismiss();
    unawaited(
      ref
          .read(appRouterProvider)
          .pushNamed(
            AppRouteNames.achievements,
            queryParameters: {
              if (batch.length == 1) 'achievementId': batch.single.id,
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((s) => s.userId), (before, after) {
      _generation++;
      _loading = false;
      _timer?.cancel();
      _seen.clear();
      _queue.clear();
      _pendingAck.clear();
      setState(() => _current = null);
      unawaited(_refresh());
    });
    ref.listen(startupGateActiveProvider, (_, active) {
      if (!active) unawaited(_refresh());
    });
    ref.listen(notificationsInboxProvider, (_, next) {
      if (next.hasValue) unawaited(_refresh());
    });
    final batch = _current;
    if (batch == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: Dismissible(
        key: ValueKey(batch.first.id),
        direction: DismissDirection.up,
        onDismissed: (_) => _dismiss(),
        child: Material(
          color: AppColors.elevatedSurface,
          elevation: 10,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 42,
                    color: AppColors.accentBlue,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.length == 1
                              ? 'Вы получили достижение'
                              : 'Вы получили ${batch.length} ${batch.length % 100 >= 11 && batch.length % 100 <= 14
                                    ? 'достижений'
                                    : batch.length % 10 >= 2 && batch.length % 10 <= 4
                                    ? 'достижения'
                                    : batch.length % 10 == 1
                                    ? 'достижение'
                                    : 'достижений'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch.length == 1
                              ? batch.single.title
                              : 'Открыть достижения',
                        ),
                      ],
                    ),
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
