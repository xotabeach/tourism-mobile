import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/route_execution/application/antifraud_hints.dart';
import 'package:tourism_mobile/features/route_execution/application/live_location_provider.dart';
import 'package:tourism_mobile/features/route_execution/application/location_sharing.dart';
import 'package:tourism_mobile/features/route_execution/application/mark_advice.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_offline_coordinator.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/application/route_start_block.dart';
import 'package:tourism_mobile/features/route_execution/data/route_execution_offline_store.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/mark_confirm_dialog.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_summary_screen.dart';
import 'package:tourism_mobile/features/routes/application/offline_routes_provider.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/map_projection.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class RouteExecutionScreen extends ConsumerStatefulWidget {
  const RouteExecutionScreen({required this.routeId, super.key});

  final String routeId;

  @override
  ConsumerState<RouteExecutionScreen> createState() =>
      _RouteExecutionScreenState();
}

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

  @override
  void dispose() {
    _clock?.cancel();
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
    final flaggedBefore = _undeliveredKeys(await store.getSnapshot());
    await coordinator.replayPending();
    final flagged = _undeliveredKeys(await store.getSnapshot());
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
    } on Object catch (error) {
      final cached = await ref
          .read(routeExecutionOfflineStoreProvider)
          .getSnapshot();
      if (cached?.routeId == widget.routeId) {
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
      if (error is NetworkFailure) {
        final downloaded = await ref
            .read(offlineRouteStoreProvider)
            .get(widget.routeId);
        if (downloaded != null) {
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

  /// Between the last marked stop and the next unmarked one; none before the
  /// first mark or after the last, and none once the run is no longer active.
  static ActiveLeg? _activeLeg(RouteExecution execution, RouteDetail? route) {
    if (!execution.isActive) return null;
    final located = [
      for (final stop in execution.stops)
        if (stop.lat != null && stop.lng != null) stop,
    ]..sort((a, b) => a.position.compareTo(b.position));
    final nextIndex = located.indexWhere((stop) => !stop.isCompleted);
    if (nextIndex <= 0) return null;
    final to = located[nextIndex];
    final from = located[nextIndex - 1];
    if (!from.isCompleted) return null;
    final line = sliceLegPolyline(
      [
        for (final point
            in route?.geometry?.coordinates ?? const <RouteCoordinate>[])
          (lat: point.lat, lng: point.lng),
      ],
      stops: located,
      from: from,
      to: to,
    );
    final fromPoint = (lat: from.lat!, lng: from.lng!);
    final toPoint = (lat: to.lat!, lng: to.lng!);
    return ActiveLeg(
      // Without route geometry the leg is drawn as a straight line.
      line: line.length >= 2 ? line : [fromPoint, toPoint],
      from: fromPoint,
      to: toPoint,
    );
  }

  static Set<String> _undeliveredKeys(RouteExecution? execution) => {
    for (final stop in execution?.stops ?? const <RouteExecutionStop>[])
      if (stop.undelivered && !stop.isCompleted) stop.routeStopId ?? stop.id,
  };

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
      final updated = _completeStopLocally(execution, stop.id, occurredAt);
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
      final updated = _completeStopLocally(execution, stop.id, occurredAt);
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

  /// The stop whose mark can be taken back: the latest one marked, so legs
  /// and pace keep following the order the stops were really reached in.
  static String? _lastMarkedStopId(RouteExecution execution) {
    RouteExecutionStop? latest;
    for (final stop in execution.stops) {
      final at = stop.completedAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest.completedAt!)) latest = stop;
    }
    return latest?.id;
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
    final updated = _uncompleteStopLocally(execution, stop.id);
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

  RouteExecution _uncompleteStopLocally(
    RouteExecution execution,
    String stopId,
  ) {
    final stops = [
      for (final stop in execution.stops)
        stop.id == stopId ? stop.withoutCompletion() : stop,
    ];
    return execution.copyWith(
      stops: stops,
      completedStops: stops.where((stop) => stop.isCompleted).length,
      completedRequiredStops: stops
          .where((stop) => stop.isCompleted && !stop.isOptional)
          .length,
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Остановить прохождение?'),
        content: const Text('Прогресс сохранится в истории как отменённый.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Остановить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
      final updated = execution.copyWith(status: RouteExecutionStatus.paused);
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
      final updated = execution.copyWith(status: RouteExecutionStatus.paused);
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

  Future<void> _resumeRoute() async {
    final execution = _execution;
    if (execution == null || execution.status != RouteExecutionStatus.paused) {
      return;
    }
    final clientEventId = newClientEventId();
    final occurredAt = DateTime.now();
    if (_isLocalPendingStart) {
      final updated = execution.copyWith(status: RouteExecutionStatus.active);
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
      final updated = execution.copyWith(status: RouteExecutionStatus.active);
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

  RouteExecution _completeStopLocally(
    RouteExecution execution,
    String stopId,
    DateTime completedAt,
  ) {
    final stops = [
      for (final stop in execution.stops)
        stop.id == stopId && !stop.isCompleted
            ? stop.copyWith(completedAt: completedAt)
            : stop,
    ];
    final completed = stops.where((stop) => stop.isCompleted).length;
    final required = stops
        .where((stop) => stop.isCompleted && !stop.isOptional)
        .length;
    return execution.copyWith(
      stops: stops,
      completedStops: completed,
      completedRequiredStops: required,
    );
  }

  Future<void> _queueOfflineAction({
    required String executionId,
    required RouteExecutionAction action,
    required RouteExecution updated,
    required String clientEventId,
    required DateTime occurredAt,
    String? stopId,
    MarkPosition? position,
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
              child: _ExecutionTopBar(
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
                  ? _ExecutionErrorView(
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
        liveLatLng != null && route != null && _isNearRoute(liveLatLng, route)
        ? liveLatLng
        : null;
    final completedFraction = _completedRouteFraction(
      execution,
      route,
      mapLivePosition,
    );
    final completedStopPositions = {
      for (final stop in execution.stops)
        if (stop.isCompleted) stop.position,
    };
    final nextStop =
        execution.status == RouteExecutionStatus.completed ||
            execution.status == RouteExecutionStatus.cancelled
        ? null
        : execution.stops.where((stop) => !stop.isCompleted).firstOrNull;
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
            color: _ExecutionColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        _ProgressCard(execution: execution),
        if (_offline) ...[
          const SizedBox(height: 12),
          _OfflineBanner(
            pendingActions: _pendingActions,
            onRetry: _retryPending,
          ),
        ],
        if (route != null) ...[
          const SizedBox(height: 12),
          RouteStaticMap(
            staticMapUrl: route.staticMapUrl,
            stops: route.stops,
            geometry: route.geometry,
            config: ref.watch(appConfigProvider),
            height: 342,
            footerLabel: execution.completedStops > 0
                ? 'Вы на ${execution.completedStops} точке'
                : routePointsLabel(route.stops.length),
            pillFooter: true,
            livePosition: mapLivePosition,
            completedFraction: completedFraction,
            completedStopPositions: completedStopPositions,
            activeLeg: _activeLeg(execution, route),
          ),
        ],
        const SizedBox(height: 8),
        _InfoRow(
          iconAsset: AppIconography.execAlarm,
          label: 'Всего в пути:',
          value: '${_elapsedMinutes(execution)} мин.',
        ),
        if (nextStopDistance != null) ...[
          const SizedBox(height: 4),
          _InfoRow(
            iconAsset: AppIconography.statRoutesCompleted,
            label: 'До след. точки',
            value: nextStopDistance,
          ),
        ],
        if (execution.routing?.warnings.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _WarningCard(warnings: execution.routing!.warnings),
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
          const _EmptyStopsCard()
        else
          for (final stop in execution.stops)
            _StopRow(
              stop: stop,
              busy: _busyStopId == stop.id,
              enabled: execution.isActive,
              onComplete: () => unawaited(_completeStop(stop)),
              onUndo:
                  execution.isActive && stop.id == _lastMarkedStopId(execution)
                  ? () => unawaited(_uncompleteStop(stop))
                  : null,
            ),
        if (execution.status == RouteExecutionStatus.paused) ...[
          const SizedBox(height: 18),
          _DarkButton(label: 'Возобновить', onPressed: _resumeRoute),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _cancelRoute,
              child: const Text('Отменить маршрут'),
            ),
          ),
          const Text(
            'Маршрут на паузе. Остановки недоступны, пока не возобновишь.',
            textAlign: TextAlign.center,
            style: _footnoteStyle,
          ),
        ],
        if (execution.isActive) ...[
          const SizedBox(height: 18),
          _DarkButton(
            label: 'Завершить маршрут',
            busy: _finishing,
            onPressed: _finishing ? null : _completeRoute,
          ),
          const SizedBox(height: 8),
          const Text(
            'Завершай остановки по мере прохождения для верного отображения истории и наград',
            textAlign: TextAlign.center,
            style: _footnoteStyle,
          ),
        ],
      ],
    );
  }

  static const _footnoteStyle = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: _ExecutionColors.muted,
  );

  /// Minutes on the way so far, pauses left out.
  static int _elapsedMinutes(RouteExecution execution) {
    final end =
        execution.completedAt ?? execution.cancelledAt ?? DateTime.now();
    final seconds =
        end.difference(execution.startedAt).inSeconds -
        execution.pausedDurationSeconds;
    return seconds <= 0 ? 0 : seconds ~/ 60;
  }

  void _showError(String message) {
    showAppNotice(context, message);
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
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

  /// Whether [position] is close enough to any stop to plausibly be a real
  /// fix for this run, rather than a stale cache or a simulator's default
  /// location. Routes are all local (Crimea is ~300km across at most), so a
  /// fix past this radius from every stop is not worth fitting the map to.
  static const _plausibleFixRadiusMeters = 150000;

  static bool _isNearRoute(
    ({double lat, double lng}) position,
    RouteDetail route,
  ) {
    for (final stop in route.stops) {
      if (stop.lat == null || stop.lng == null) {
        continue;
      }
      final distance = Geolocator.distanceBetween(
        position.lat,
        position.lng,
        stop.lat!,
        stop.lng!,
      );
      if (distance <= _plausibleFixRadiusMeters) {
        return true;
      }
    }
    return false;
  }

  /// How far along [route]'s geometry the walk has gotten. Null when nothing
  /// is completed yet or there's no geometry to color.
  ///
  /// Two references, whichever is further along: the last completed stop, and
  /// the walker's current position. The stop alone is not enough — the first
  /// stop sits on the geometry's first point, so checking it off would color
  /// nothing at all; [livePosition] is what makes the line grow while walking
  /// the leg towards the next stop.
  static double? _completedRouteFraction(
    RouteExecution execution,
    RouteDetail? route,
    ({double lat, double lng})? livePosition,
  ) {
    final coordinates = route?.geometry?.coordinates;
    if (coordinates == null || coordinates.length < 2) {
      return null;
    }
    RouteExecutionStop? furthest;
    for (final stop in execution.stops) {
      if (!stop.isCompleted || stop.lat == null || stop.lng == null) {
        continue;
      }
      if (furthest == null || stop.position > furthest.position) {
        furthest = stop;
      }
    }
    if (furthest == null) {
      return null;
    }
    final points = [for (final c in coordinates) (lat: c.lat, lng: c.lng)];
    final reached = MapProjection.completedFraction(
      coordinates: points,
      reference: (lat: furthest.lat!, lng: furthest.lng!),
    );
    if (livePosition == null) {
      return reached;
    }
    final walked = MapProjection.completedFraction(
      coordinates: points,
      reference: livePosition,
    );
    return walked > reached ? walked : reached;
  }
}

class _ExecutionColors {
  static const muted = Color(0xFF8E8E93);
  static const track = Color(0xFFD6E4F7);
  static const ring = Color(0xFFD9D9D9);

  /// DESIGN-4 «не доставлена» red (#FF383C, same as the cross icon).
  static const error = Color(0xFFFF383C);
}

/// Back on the left, the title in the middle and the pause (or resume)
/// control on the right, as in the design.
class _ExecutionTopBar extends StatelessWidget {
  const _ExecutionTopBar({
    required this.onBack,
    required this.onPause,
    required this.onResume,
  });

  final VoidCallback onBack;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final onPause = this.onPause;
    final onResume = this.onResume;
    return SizedBox(
      height: SettingsMetrics.headerButton,
      child: Row(
        children: [
          Semantics(
            label: 'Назад',
            button: true,
            excludeSemantics: true,
            child: SettingsCircleIconButton(
              icon: Icons.arrow_back_rounded,
              iconSize: 22,
              onTap: onBack,
            ),
          ),
          Expanded(
            child: Text(
              'Прохождение',
              textAlign: TextAlign.center,
              style: AppTypography.settingsRowTitle.copyWith(fontSize: 16),
            ),
          ),
          if (onPause != null)
            Semantics(
              label: 'Пауза',
              button: true,
              excludeSemantics: true,
              child: SettingsCircleIconButton(
                icon: Icons.pause_rounded,
                iconSize: 30,
                onTap: onPause,
              ),
            )
          else if (onResume != null)
            Semantics(
              label: 'Возобновить',
              button: true,
              excludeSemantics: true,
              child: SettingsCircleIconButton(
                icon: Icons.play_arrow_rounded,
                iconSize: 30,
                onTap: onResume,
              ),
            )
          else
            const SizedBox(width: SettingsMetrics.headerButton),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.execution});

  final RouteExecution execution;

  static const _label = TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: _ExecutionColors.muted,
  );

  @override
  Widget build(BuildContext context) {
    final percent = (execution.progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Прогресс:', style: _label),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: execution.progress,
                backgroundColor: _ExecutionColors.track,
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(height: 10),
            if (execution.totalStops == 0)
              const Text(
                'Остановки появятся после синхронизации маршрута',
                style: _label,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Остановки:',
                    style: _label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${execution.completedStops}/${execution.totalStops}',
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// «Всего в пути: 174 мин.»: a pill with a blue icon, the label on the left
/// and the value on the right.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        height: 43,
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEFEFF1)),
        ),
        child: Row(
          children: [
            AppAssetIcon(iconAsset, size: 24, color: AppColors.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: _ExecutionColors.muted,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppColors.primaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryInk,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pendingActions, required this.onRetry});

  final int pendingActions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.accentBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pendingActions == 0
                    ? 'Офлайн-сеанс. Данные сохранены на устройстве.'
                    : 'Офлайн-сеанс. Действий к синхронизации: $pendingActions.',
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.primaryInk,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.busy,
    required this.enabled,
    required this.onComplete,
    this.onUndo,
  });

  final RouteExecutionStop stop;
  final bool busy;
  final bool enabled;
  final VoidCallback onComplete;

  /// Set only for the latest marked stop: tapping its tick takes it back.
  final VoidCallback? onUndo;

  String get _subtitle {
    final parts = [
      // Leg length, with the expected time when there is one.
      ?formatLegLabel(stop.legDistanceMeters, stop.legEstimateSeconds) ??
          (stop.legDistanceMeters == null
              ? null
              : formatDistanceKm(stop.legDistanceMeters)),
      if (stop.isOptional) 'Можно пропустить',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final done = stop.isCompleted;
    // A mark made offline that the server never got (DESIGN-4, №3): a red
    // cross in place of the ring and a short red note, tap marks it again.
    final undelivered = stop.undelivered && !done;
    final subtitle = _subtitle;
    return SizedBox(
      height: 47,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryInk,
            ),
            alignment: Alignment.center,
            child: Text(
              '${stop.position}',
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: AppColors.primaryInk,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                      color: _ExecutionColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (undelivered && !busy) ...[
            const ExcludeSemantics(
              child: Text(
                'Что-то пошло не так,\nпопробуйте ещё раз.',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: _ExecutionColors.error,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          _StopMark(
            done: done,
            undelivered: undelivered,
            busy: busy,
            placeName: stop.placeName,
            onTap: busy
                ? null
                : done
                ? onUndo
                : enabled
                ? onComplete
                : null,
          ),
        ],
      ),
    );
  }
}

/// The round mark on the right of a stop: an empty ring to tap when the
/// stop is reached, filled with a tick once it is.
class _StopMark extends StatelessWidget {
  const _StopMark({
    required this.done,
    required this.busy,
    required this.placeName,
    required this.onTap,
    this.undelivered = false,
  });

  final bool done;
  final bool undelivered;
  final bool busy;
  final String placeName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: !done || onTap != null,
      checked: done,
      enabled: onTap != null,
      label: undelivered
          ? 'Отметка «$placeName» не доставлена, отметить заново'
          : !done
          ? 'Отметить «$placeName»'
          : onTap != null
          ? '«$placeName» отмечена, снять отметку'
          : '«$placeName» отмечена',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: undelivered && !busy
                ? Image.asset(
                    AppIconography.execUndelivered,
                    width: 31,
                    height: 31,
                  )
                : Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primaryInk : Colors.transparent,
                      border: done
                          ? null
                          : Border.all(
                              color: _ExecutionColors.ring,
                              width: 1.2,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9A6500)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Проверь актуальность дороги и погоды перед выходом. ${warnings.take(2).join(', ')}',
                style: AppTypography.routeMetadata.copyWith(
                  color: const Color(0xFF6E4B00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStopsCard extends StatelessWidget {
  const _EmptyStopsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Маршрут можно начать. Остановки синхронизируются после ответа сервера.',
        ),
      ),
    );
  }
}

/// Execution-start failure with the real reason, plus a way out when the
/// blocker is another route already in progress — otherwise this screen is a
/// dead end for anyone who forgot to finish a walk.
class _ExecutionErrorView extends StatelessWidget {
  const _ExecutionErrorView({
    required this.message,
    required this.onRetry,
    required this.onOpenBlocking,
    this.blocking,
  });

  final String message;
  final RouteExecution? blocking;
  final VoidCallback onRetry;
  final VoidCallback onOpenBlocking;

  @override
  Widget build(BuildContext context) {
    final blockingRoute = blocking;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_walk_rounded, size: 32),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (blockingRoute != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Сейчас проходится «${blockingRoute.routeName}»',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (blockingRoute != null)
                FilledButton.icon(
                  onPressed: onOpenBlocking,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Открыть активный маршрут'),
                ),
              if (blockingRoute != null) const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
