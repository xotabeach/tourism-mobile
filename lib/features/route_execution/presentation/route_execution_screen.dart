import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/route_execution/application/active_leg.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/application/home_active_run.dart';
import 'package:tourism_mobile/features/route_execution/application/live_location_provider.dart';
import 'package:tourism_mobile/features/route_execution/application/local_run_changes.dart';
import 'package:tourism_mobile/features/route_execution/application/location_sharing.dart';
import 'package:tourism_mobile/features/route_execution/application/mark_advice.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/application/route_start_block.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/mark_confirm_dialog.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_summary_screen.dart';
import 'package:tourism_mobile/features/route_execution/presentation/run_confirm_dialogs.dart';
import 'package:tourism_mobile/features/route_execution/presentation/skip_stop_sheet.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/active_leg_card.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_actions.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_chrome.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_map.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_progress.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_stop_list.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_line_style.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RouteExecutionScreen extends ConsumerStatefulWidget {
  const RouteExecutionScreen({
    required this.routeId,
    this.openOnly = false,
    super.key,
  });

  final String routeId;

  /// Opened from the home card (FRONTEND-34): show the run in progress, but
  /// never start a new one — it may have been finished on another device.
  final bool openOnly;

  @override
  ConsumerState<RouteExecutionScreen> createState() =>
      _RouteExecutionScreenState();
}

/// API code of a start refused because another run is in progress.
@visibleForTesting
const activeRunConflictCode = 'active_route_execution_exists';

/// Offline, the previous run's start has not reached the server yet.
@visibleForTesting
const offlineStartWaitsMessage =
    'Прошлое прохождение ещё не отправлено.\n'
    'Подключитесь к сети, чтобы начать новый маршрут.';

class _RouteExecutionScreenState extends ConsumerState<RouteExecutionScreen> {
  RouteExecution? _execution;
  String? _error;
  // Set when another route is already being walked: the screen is otherwise a
  // dead end (the user cannot start this route and cannot reach the blocking
  // one from here).
  RouteExecution? _blockingExecution;
  var _loading = true;
  String? _busyStopId;
  var _finishing = false;
  var _offline = false;
  var _pendingActions = 0;
  // After a confirmed prompt, further marks within a minute are not asked again.
  DateTime? _promptConfirmedAt;

  /// Ticks «Всего в пути» over while the screen is open.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _execution?.isActive == true) setState(() {});
    });
    unawaited(_loadOrStart());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_explainLocation());
    });
  }

  // Kept from build: ref is off limits in dispose.
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _clock?.cancel();
    // Whatever happened here (marks, a pause, the finish), the home card of
    // the run is out of date now (FRONTEND-34).
    _container?.invalidate(homeActiveRunProvider);
    super.dispose();
  }

  Future<void> _explainLocation() async {
    if (!mounted) return;
    await explainLocationOnce(context, ref);
    // The live-position stream read the permission before it was granted.
    if (mounted) ref.invalidate(liveLocationProvider);
  }

  PositionFix? _currentFix() {
    final position = ref.read(liveLocationProvider).valueOrNull;
    if (position == null) return null;
    return PositionFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracyMeters: position.accuracy,
      takenAt: position.timestamp,
    );
  }

  /// Asks before sending a mark that looks early. Cancelling sends nothing,
  /// so it costs the person nothing; the server stays the judge either way.
  Future<bool> _confirmMark(MarkAdvice advice) async {
    final recent = _promptConfirmedAt;
    if (recent != null &&
        DateTime.now().difference(recent) < const Duration(seconds: 60)) {
      return true;
    }
    final confirmed = await showMarkConfirmDialog(
      context,
      notThereYet: advice.isAhead,
    );
    if (confirmed) _promptConfirmedAt = DateTime.now();
    return confirmed;
  }

  Future<void> _loadOrStart() async {
    final coordinator = ref.read(routeExecutionOfflineCoordinatorProvider);
    final store = ref.read(routeExecutionOfflineStoreProvider);
    final flaggedBefore = undeliveredKeys(await store.getSnapshot());
    await coordinator.replayPending();
    final flagged = undeliveredKeys(await store.getSnapshot());
    final newlyDropped = flagged.difference(flaggedBefore);
    try {
      final repository = ref.read(routeExecutionRepositoryProvider);
      final active = await repository.getActive();
      // A paused run still counts as "the one you're on" — getActive()
      // already returns it (see get_active_execution), so it must block a
      // different route here the same way an active run does.
      final inProgress =
          active?.status == RouteExecutionStatus.active ||
          active?.status == RouteExecutionStatus.paused;
      if (active != null && inProgress && active.routeId != widget.routeId) {
        if (mounted) {
          setState(() => _blockingExecution = active);
        }
        throw StateError('Сначала заверши текущий маршрут');
      }
      if (mounted && _blockingExecution != null) {
        setState(() => _blockingExecution = null);
      }
      final ownRun = active?.routeId == widget.routeId && inProgress;
      if (widget.openOnly && !ownRun) {
        throw const _RunAlreadyOver();
      }
      final fetched = active?.routeId == widget.routeId
          ? active!
          : await repository.start(widget.routeId);
      // The server does not know about marks that never arrived, so the note
      // travels with the local snapshot and is re-applied to fresh data.
      final execution = fetched.copyWith(
        stops: [
          for (final stop in fetched.stops)
            flagged.contains(stop.routeStopId ?? stop.id) && !stop.isCompleted
                ? stop.copyWith(undelivered: true)
                : stop,
        ],
      );
      if (!mounted) return;
      // Starting worked, so any remembered block is over.
      unawaited(
        ref
            .read(routeStartBlockStoreProvider)
            .clear()
            .then((_) => ref.invalidate(routeStartBlockedUntilProvider)),
      );
      if (newlyDropped.isNotEmpty) {
        final names = [
          for (final stop in execution.stops)
            if (newlyDropped.contains(stop.routeStopId ?? stop.id))
              '«${stop.placeName}»',
        ];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && names.isNotEmpty) {
            _showError(
              'Отметка ${names.join(', ')} не доставлена — отметьте её заново',
            );
          }
        });
      }
      await coordinator.save(execution);
      await _refreshPendingActions();
      setState(() {
        _execution = execution;
        _loading = false;
        _offline = false;
      });
    } on RouteStartBlockedFailure catch (blocked) {
      final until = blocked.blockedUntil;
      if (until != null) {
        await ref.read(routeStartBlockStoreProvider).write(until);
        ref.invalidate(routeStartBlockedUntilProvider);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = blockedStartMessage(until, DateTime.now());
      });
    } on _RunAlreadyOver {
      // The card was stale: drop it and say so instead of starting again.
      ref.invalidate(homeActiveRunProvider);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Прохождение уже завершено';
      });
    } on Object catch (error) {
      if (error is AppFailure && error.code == activeRunConflictCode) {
        // Another device started a run between the check above and this
        // start: name it instead of a bare refusal.
        RouteExecution? blocking;
        try {
          blocking = await ref
              .read(routeExecutionRepositoryProvider)
              .getActive();
        } on Object {
          blocking = null;
        }
        if (!mounted) return;
        setState(() {
          _blockingExecution = blocking;
          _loading = false;
          _error = 'Сначала заверши текущий маршрут';
        });
        return;
      }
      final cached = await ref
          .read(routeExecutionOfflineStoreProvider)
          .getSnapshot();
      final cachedInProgress =
          cached?.status == RouteExecutionStatus.active ||
          cached?.status == RouteExecutionStatus.paused;
      if (cached?.routeId == widget.routeId &&
          (!widget.openOnly || cachedInProgress)) {
        if (!mounted) return;
        await _refreshPendingActions();
        setState(() {
          _execution = cached;
          _loading = false;
          _offline = true;
          _error = null;
        });
        return;
      }
      // No run in progress at all yet — if this route was downloaded, a
      // brand-new offline start is possible; the "start" outbox entry
      // reconciles with the server once connectivity returns.
      if (error is NetworkFailure && !widget.openOnly) {
        final downloaded = await ref
            .read(offlineRouteStoreProvider)
            .get(widget.routeId);
        if (downloaded != null) {
          // The device keeps one run: starting another offline would
          // overwrite the one in progress and queue a start the server
          // refuses once back online.
          if (cached != null && cachedInProgress) {
            if (!mounted) return;
            setState(() {
              _blockingExecution = cached;
              _loading = false;
              _error = 'Сначала заверши текущий маршрут';
            });
            return;
          }
          final unsentStart = (await store.listOutbox()).any(
            (entry) => entry.action == RouteExecutionAction.start,
          );
          if (unsentStart) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = offlineStartWaitsMessage;
            });
            return;
          }
          final execution = await ref
              .read(routeExecutionOfflineCoordinatorProvider)
              .startOffline(downloaded.route);
          if (!mounted) return;
          await _refreshPendingActions();
          setState(() {
            _execution = execution;
            _loading = false;
            _offline = true;
            _error = null;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  bool get _isLocalPendingStart =>
      _execution?.id.startsWith(
        RouteExecutionOfflineCoordinator.localExecutionPrefix,
      ) ??
      false;

  Future<void> _completeStop(RouteExecutionStop stop) async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _busyStopId != null) return;
    final fix = _currentFix();
    final advice = adviseMark(
      execution: execution,
      stop: stop,
      fix: fix,
      now: DateTime.now(),
    );
    if (advice.needsConfirmation && !await _confirmMark(advice)) return;
    if (!mounted) return;
    setState(() => _busyStopId = stop.id);
    // One key for the attempt and its queued retry: if the request reached the
    // server before the connection dropped, the replay is deduped.
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    final position = positionToSend(
      execution: execution,
      fix: fix,
      sharingEnabled: ref.read(locationSharingProvider).shareEnabled,
      now: occurredAt,
    );
    if (_isLocalPendingStart) {
      final updated = completeStopLocally(execution, stop.id, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.completeStop,
        stopId: stop.id,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        position: position,
        updated: updated,
      );
      if (mounted) setState(() => _busyStopId = null);
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .completeStop(
            execution.id,
            stop.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
            position: position,
          );
      // The response carries fresh thresholds; remember the pause total this
      // mark was made at so the next pace hint can net out pauses.
      final saved = updated.copyWith(
        pausedAtLastMarkSeconds: updated.pausedDurationSeconds,
      );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(saved);
      if (mounted) setState(() => _execution = saved);
      ref.invalidate(routeExecutionHistoryProvider);
    } on Object catch (error) {
      if (error is! NetworkFailure) {
        if (mounted) _showError(_friendlyError(error));
        return;
      }
      final updated = completeStopLocally(execution, stop.id, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.completeStop,
        stopId: stop.id,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        position: position,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyStopId = null);
    }
  }

  Future<void> _uncompleteStop(RouteExecutionStop stop) async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _busyStopId != null) return;
    final confirmed = await showUnmarkConfirmDialog(
      context,
      placeName: stop.placeName,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyStopId = stop.id);
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    final updated = uncompleteStopLocally(execution, stop.id);
    final coordinator = ref.read(routeExecutionOfflineCoordinatorProvider);
    try {
      // A mark still waiting to be sent is simply withdrawn.
      if (await coordinator.withdrawQueuedMark(execution.id, stop.id)) {
        await coordinator.save(updated);
        await _refreshPendingActions();
        if (mounted) setState(() => _execution = updated);
        return;
      }
      final saved = await ref
          .read(routeExecutionRepositoryProvider)
          .uncompleteStop(
            execution.id,
            stop.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await coordinator.save(saved);
      if (mounted) setState(() => _execution = saved);
      ref.invalidate(routeExecutionHistoryProvider);
    } on NetworkFailure catch (error) {
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.uncompleteStop,
        stopId: stop.id,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyStopId = null);
    }
  }

  Future<void> _skipStop(RouteExecutionStop stop) async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _busyStopId != null) return;
    final reason = await showSkipStopSheet(context, placeName: stop.placeName);
    if (reason == null || !mounted) return;
    setState(() => _busyStopId = stop.id);
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    final updated = skipStopLocally(execution, stop.id, reason, occurredAt);
    Future<void> queue() => _queueOfflineAction(
      executionId: execution.id,
      action: RouteExecutionAction.skipStop,
      stopId: stop.id,
      clientEventId: clientEventId,
      occurredAt: occurredAt,
      skipReason: reason,
      updated: updated,
    );
    try {
      if (_isLocalPendingStart) {
        await queue();
        return;
      }
      final saved = await ref
          .read(routeExecutionRepositoryProvider)
          .skipStop(
            execution.id,
            stop.id,
            reason: reason,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(saved);
      if (mounted) setState(() => _execution = saved);
    } on NetworkFailure catch (error) {
      await queue();
      if (mounted) _showError(_friendlyError(error));
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyStopId = null);
    }
  }

  Future<void> _unskipStop(RouteExecutionStop stop) async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _busyStopId != null) return;
    setState(() => _busyStopId = stop.id);
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    final updated = unskipStopLocally(execution, stop.id);
    final coordinator = ref.read(routeExecutionOfflineCoordinatorProvider);
    Future<void> queue() => _queueOfflineAction(
      executionId: execution.id,
      action: RouteExecutionAction.unskipStop,
      stopId: stop.id,
      clientEventId: clientEventId,
      occurredAt: occurredAt,
      updated: updated,
    );
    try {
      if (_isLocalPendingStart) {
        await queue();
        return;
      }
      // A skip still waiting to be sent is simply withdrawn.
      if (await coordinator.withdrawQueuedSkip(execution.id, stop.id)) {
        await coordinator.save(updated);
        await _refreshPendingActions();
        if (mounted) setState(() => _execution = updated);
        return;
      }
      final saved = await ref
          .read(routeExecutionRepositoryProvider)
          .unskipStop(
            execution.id,
            stop.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await coordinator.save(saved);
      if (mounted) setState(() => _execution = saved);
    } on NetworkFailure catch (error) {
      await queue();
      if (mounted) _showError(_friendlyError(error));
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyStopId = null);
    }
  }

  Future<void> _completeRoute() async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _finishing) return;
    setState(() => _finishing = true);
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    if (_isLocalPendingStart) {
      final updated = execution.copyWith(
        status: RouteExecutionStatus.completed,
        completedAt: occurredAt,
      );
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.complete,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) {
        setState(() => _finishing = false);
        await _showSummary(updated);
      }
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .complete(
            execution.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) {
        setState(() => _execution = updated);
        await _showSummary(updated);
      }
      ref.invalidate(routeExecutionHistoryProvider);
    } on Object catch (error) {
      if (error is! NetworkFailure) {
        if (mounted) _showError(_friendlyError(error));
        return;
      }
      final updated = execution.copyWith(
        status: RouteExecutionStatus.completed,
        completedAt: occurredAt,
      );
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.complete,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _showSummary(RouteExecution execution) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RouteExecutionSummaryScreen(execution: execution),
      ),
    );
  }

  /// Active or paused — the run in progress must expose cancel either way;
  /// only complete/complete_stop stay gated to strictly active.
  bool get _isInProgress =>
      _execution?.status == RouteExecutionStatus.active ||
      _execution?.status == RouteExecutionStatus.paused;

  Future<void> _cancelRoute() async {
    final execution = _execution;
    if (execution == null || !_isInProgress) return;
    final confirmed = await showCancelRunDialog(context);
    if (!confirmed || !mounted) return;
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    if (_isLocalPendingStart) {
      final updated = execution.copyWith(
        status: RouteExecutionStatus.cancelled,
        cancelledAt: occurredAt,
      );
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.cancel,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .cancel(
            execution.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) setState(() => _execution = updated);
      ref.invalidate(routeExecutionHistoryProvider);
    } on Object catch (error) {
      if (error is! NetworkFailure) {
        if (mounted) _showError(_friendlyError(error));
        return;
      }
      final updated = execution.copyWith(
        status: RouteExecutionStatus.cancelled,
        cancelledAt: occurredAt,
      );
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.cancel,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    }
  }

  Future<void> _pauseRoute() async {
    final execution = _execution;
    if (execution == null || execution.status != RouteExecutionStatus.active) {
      return;
    }
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    if (_isLocalPendingStart) {
      final updated = pausedLocally(execution, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.pause,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .pause(
            execution.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) setState(() => _execution = updated);
    } on Object catch (error) {
      if (error is! NetworkFailure) {
        if (mounted) _showError(_friendlyError(error));
        return;
      }
      final updated = pausedLocally(execution, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.pause,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    }
  }

  /// «Закончить день» of a multi-day run (spec 14a). Online only: the
  /// night pause changes what the server pays, so it is not queued.
  Future<void> _endDay() async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _isLocalPendingStart) {
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .endDay(execution.id);
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) setState(() => _execution = updated);
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  /// «Завершить многодневный маршрут»: the finished days are still paid.
  Future<void> _finishEarly() async {
    final execution = _execution;
    if (execution == null || !_isInProgress || _isLocalPendingStart) return;
    final confirmed = await showFinishEarlyDialog(context);
    if (!confirmed || !mounted) return;
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .finishEarly(execution.id);
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) setState(() => _execution = updated);
      ref.invalidate(routeExecutionHistoryProvider);
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  Future<void> _resumeRoute() async {
    final execution = _execution;
    if (execution == null || execution.status != RouteExecutionStatus.paused) {
      return;
    }
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    if (_isLocalPendingStart) {
      final updated = resumedLocally(execution, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.resume,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      return;
    }
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .resume(
            execution.id,
            clientEventId: clientEventId,
            occurredAt: occurredAt,
          );
      await ref.read(routeExecutionOfflineCoordinatorProvider).save(updated);
      if (mounted) setState(() => _execution = updated);
    } on Object catch (error) {
      if (error is! NetworkFailure) {
        if (mounted) _showError(_friendlyError(error));
        return;
      }
      final updated = resumedLocally(execution, occurredAt);
      await _queueOfflineAction(
        executionId: execution.id,
        action: RouteExecutionAction.resume,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        updated: updated,
      );
      if (mounted) _showError(_friendlyError(error));
    }
  }

  Future<void> _queueOfflineAction({
    required String executionId,
    required RouteExecutionAction action,
    required RouteExecution updated,
    required String clientEventId,
    required DateTime occurredAt,
    String? stopId,
    MarkPosition? position,
    StopSkipReason? skipReason,
  }) async {
    final coordinator = ref.read(routeExecutionOfflineCoordinatorProvider);
    await coordinator.save(updated);
    // A run that hasn't synced its own "start" yet has no server-side target
    // for these mutations - replayPending() catches the real execution up to
    // this local snapshot's state once "start" itself succeeds. Stop marks are
    // still queued, though: the start replay reads their event id and position
    // from those entries and consumes them, so they are never sent twice.
    final isLocal = executionId.startsWith(
      RouteExecutionOfflineCoordinator.localExecutionPrefix,
    );
    if (!isLocal || action == RouteExecutionAction.completeStop) {
      await coordinator.enqueue(
        executionId: executionId,
        action: action,
        stopId: stopId,
        clientEventId: clientEventId,
        occurredAt: occurredAt,
        position: position,
        skipReason: skipReason,
      );
    }
    await _refreshPendingActions();
    if (mounted) {
      setState(() {
        _execution = updated;
        _offline = true;
      });
    }
  }

  Future<void> _refreshPendingActions() async {
    final count =
        (await ref.read(routeExecutionOfflineStoreProvider).listOutbox())
            .length;
    if (mounted) setState(() => _pendingActions = count);
  }

  Future<void> _retryPending() async {
    try {
      final updated = await ref
          .read(routeExecutionOfflineCoordinatorProvider)
          .replayPending();
      await _refreshPendingActions();
      if (updated != null && mounted) {
        setState(() {
          _execution = updated;
          _offline = _pendingActions > 0;
        });
      }
      if (mounted && _pendingActions == 0) {
        _showError('Прогресс синхронизирован');
      }
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(routeDetailProvider(widget.routeId));
    final route = routeAsync.asData?.value;
    final status = _execution?.status;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ExecutionTopBar(
                onBack: () => context.pop(),
                // The pause control sits in the corner as drawn; a paused run
                // resumes from the same place.
                onPause: status == RouteExecutionStatus.active
                    ? _pauseRoute
                    : null,
                onResume: status == RouteExecutionStatus.paused
                    ? _resumeRoute
                    : null,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ExecutionErrorView(
                      message: _error!,
                      blocking: _blockingExecution,
                      onRetry: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                        });
                        unawaited(_loadOrStart());
                      },
                      onOpenBlocking: () {
                        final blocking = _blockingExecution;
                        final blockingRouteId = blocking?.routeId;
                        if (blockingRouteId == null) return;
                        context.pushReplacementNamed(
                          AppRouteNames.routeExecution,
                          pathParameters: {'id': blockingRouteId},
                        );
                      },
                    )
                  : _execution == null
                  ? const Center(child: Text('Не удалось открыть прохождение'))
                  : _buildContent(_execution!, route),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RouteExecution execution, RouteDetail? route) {
    final title = route?.name ?? execution.routeName;
    // GPS is only worth reading while the run is actually in progress — no
    // point tracking position on a finished or cancelled screen.
    final livePosition = execution.isActive
        ? ref.watch(liveLocationProvider).valueOrNull
        : null;
    final liveLatLng = livePosition == null
        ? null
        : (lat: livePosition.latitude, lng: livePosition.longitude);
    // A stray fix (stale cache, simulator default location, no GPS lock yet)
    // can land hundreds of km from the route — feeding that into the map's
    // fit would zoom it out to a near-global view instead of the route
    // itself. The distance row below is still shown as-is: an implausible
    // distance there just reads as "very far", not broken.
    final mapLivePosition =
        liveLatLng != null && route != null && isFixNearRoute(liveLatLng, route)
        ? liveLatLng
        : null;
    final nextStop =
        execution.status == RouteExecutionStatus.completed ||
            execution.status == RouteExecutionStatus.cancelled
        ? null
        : execution.stops.where((stop) => !stop.isSettled).firstOrNull;
    // To the next stop from where the phone is, as the crow flies; without a
    // plausible fix, the length of the whole leg that leads there along the
    // way. The two are different numbers, so the row says which one it shows
    // (FRONTEND-36: they used to share one unlabelled value and jump).
    final nextStopDistance =
        mapLivePosition != null &&
            nextStop?.lat != null &&
            nextStop?.lng != null
        ? '${formatStopDistance(Geolocator.distanceBetween(mapLivePosition.lat, mapLivePosition.lng, nextStop!.lat!, nextStop.lng!).round())} по прямой'
        : nextStop?.legDistanceMeters == null
        ? null
        : 'весь участок ${formatStopDistance(nextStop!.legDistanceMeters!)}';
    final legInfo = activeLegInfo(execution);
    final map = route == null
        ? null
        : executionMap(
            route: route,
            execution: execution,
            config: ref.watch(appConfigProvider),
            livePosition: mapLivePosition,
          );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _statusLabel(execution.status),
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: ExecutionColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        ExecutionProgressCard(execution: execution),
        if (execution.isMultiDay) ...[
          const SizedBox(height: 10),
          Text(
            dayOfRunLabel(execution),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryInk,
            ),
          ),
        ],
        if (_offline) ...[
          const SizedBox(height: 12),
          ExecutionOfflineBanner(
            pendingActions: _pendingActions,
            onRetry: _retryPending,
          ),
        ],
        if (legInfo != null) ...[
          const SizedBox(height: 12),
          ActiveLegCard(
            leg: legInfo,
            onShowOnMap: map?.activeLeg == null
                ? null
                : () => unawaited(
                    showRouteMapFullScreen(context, map!, focusOnLeg: true),
                  ),
          ),
        ],
        if (map != null) ...[const SizedBox(height: 12), map],
        const SizedBox(height: 8),
        ExecutionInfoRow(
          iconAsset: AppIconography.execAlarm,
          label: 'Всего в пути:',
          value: '${_elapsedMinutes(execution)} мин.',
        ),
        if (nextStopDistance != null) ...[
          const SizedBox(height: 4),
          ExecutionInfoRow(
            iconAsset: AppIconography.statRoutesCompleted,
            label: 'До след. точки',
            value: nextStopDistance,
          ),
        ],
        if (execution.routing?.warnings.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          ExecutionWarningCard(warnings: execution.routing!.warnings),
        ],
        const SizedBox(height: 24),
        const Text(
          'Остановки:',
          style: TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
        const SizedBox(height: 8),
        if (execution.stops.isEmpty)
          const ExecutionEmptyStopsCard()
        else
          for (final stop in execution.stops) ...[
            ExecutionStopRow(
              stop: stop,
              isNext: execution.isActive && stop.id == nextStop?.id,
              travelSummary: legTravelSummary(
                route?.segmentsTo(stop.position - 1) ?? const [],
              ),
              busy: _busyStopId == stop.id,
              enabled: execution.isActive,
              onComplete: () => unawaited(_completeStop(stop)),
              onUndo:
                  execution.isActive && stop.id == lastMarkedStopId(execution)
                  ? () => unawaited(_uncompleteStop(stop))
                  : null,
              onUnskip: execution.isActive
                  ? () => unawaited(_unskipStop(stop))
                  : null,
            ),
            if (execution.isActive && stop.id == nextStop?.id)
              ExecutionSkipLink(
                placeName: stop.placeName,
                onPressed: _busyStopId == null
                    ? () => unawaited(_skipStop(stop))
                    : null,
              ),
          ],
        ...executionActions(
          execution: execution,
          finishing: _finishing,
          onResume: _resumeRoute,
          onCancel: _cancelRoute,
          onFinishEarly: _finishEarly,
          onComplete: _completeRoute,
          onEndDay: _endDay,
        ),
      ],
    );
  }

  /// Minutes on the way so far, pauses left out.
  static int _elapsedMinutes(RouteExecution execution) =>
      execution.elapsed(DateTime.now()).inMinutes;

  void _showError(String message) {
    showAppNotice(context, message);
  }

  static String _friendlyError(Object error) {
    if (error is AppFailure && error.code == activeRunConflictCode) {
      return 'Сначала заверши текущий маршрут';
    }
    final message = error.toString();
    if (error is AppFailure && error.code == 'required_stops_incomplete') {
      return 'Отметь или пропусти обязательные точки, чтобы завершить';
    }
    if (error is AppFailure && error.code == 'no_stops_marked') {
      return 'Отметь хотя бы одну точку, чтобы завершить';
    }
    if (message.contains('route_execution_stop_not_last')) {
      return 'Снять можно только последнюю отметку';
    }
    if (message.contains('текущий маршрут')) {
      return 'Сначала заверши текущий маршрут';
    }
    if (message.contains('409')) return 'Маршрут нельзя начать сейчас';
    if (message.contains('Network') || message.contains('connection')) {
      return 'Нет соединения. Попробуй ещё раз';
    }
    return 'Не удалось обновить прохождение';
  }

  static String _statusLabel(RouteExecutionStatus status) {
    return switch (status) {
      RouteExecutionStatus.active => 'Маршрут начат — сохраняем прогресс',
      RouteExecutionStatus.paused => 'На паузе',
      RouteExecutionStatus.completed => 'Маршрут завершён',
      RouteExecutionStatus.cancelled => 'Прохождение отменено',
    };
  }
}

/// Open-only mode found no run of this route in progress.
class _RunAlreadyOver implements Exception {
  const _RunAlreadyOver();
}

/// «День 2 из 3», or «День 5 (по плану 4)» for a walker taking longer.
@visibleForTesting
String dayOfRunLabel(RouteExecution execution) =>
    execution.currentDay > execution.plannedDays
    ? 'День ${execution.currentDay} (по плану ${execution.plannedDays})'
    : 'День ${execution.currentDay} из ${execution.plannedDays}';
