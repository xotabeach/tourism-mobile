import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_async_error.dart';
import 'package:tourism_mobile/features/route_execution/application/route_execution_providers.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_map_preview.dart';

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
  var _loading = true;
  String? _busyStopId;
  var _finishing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrStart());
  }

  Future<void> _loadOrStart() async {
    try {
      final repository = ref.read(routeExecutionRepositoryProvider);
      final active = await repository.getActive();
      if (active != null &&
          active.isActive &&
          active.routeId != widget.routeId) {
        throw StateError('Сначала заверши текущий маршрут');
      }
      final execution = active?.routeId == widget.routeId
          ? active!
          : await repository.start(widget.routeId);
      if (!mounted) return;
      setState(() {
        _execution = execution;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _completeStop(RouteExecutionStop stop) async {
    final execution = _execution;
    if (execution == null || !execution.isActive || _busyStopId != null) return;
    setState(() => _busyStopId = stop.id);
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .completeStop(execution.id, stop.id);
      if (mounted) setState(() => _execution = updated);
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
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .complete(execution.id);
      if (mounted) setState(() => _execution = updated);
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _cancelRoute() async {
    final execution = _execution;
    if (execution == null || !execution.isActive) return;
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
    try {
      final updated = await ref
          .read(routeExecutionRepositoryProvider)
          .cancel(execution.id);
      if (mounted) setState(() => _execution = updated);
    } on Object catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(routeDetailProvider(widget.routeId));
    final route = routeAsync.asData?.value;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        title: const Text('Прохождение'),
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (_execution?.isActive == true)
            IconButton(
              tooltip: 'Отменить',
              onPressed: _cancelRoute,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppAsyncErrorView(
              onRetry: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                unawaited(_loadOrStart());
              },
            )
          : _execution == null
          ? const Center(child: Text('Не удалось открыть прохождение'))
          : _buildContent(_execution!, route),
    );
  }

  Widget _buildContent(RouteExecution execution, RouteDetail? route) {
    final completed = execution.status == RouteExecutionStatus.completed;
    final cancelled = execution.status == RouteExecutionStatus.cancelled;
    final title = route?.name ?? execution.routeName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
      children: [
        Text(
          title,
          style: AppTypography.routeTitle.copyWith(
            fontSize: 27,
            color: AppColors.primaryInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _statusLabel(execution.status),
          style: AppTypography.coach.copyWith(color: AppColors.secondaryInk),
        ),
        const SizedBox(height: 18),
        _ProgressCard(execution: execution),
        if (route != null) ...[
          const SizedBox(height: 18),
          RouteMapPreview(
            stops: route.stops,
            geometry: route.geometry,
            selectedIndex: null,
            onPinTap: (_) {},
          ),
        ],
        if (execution.routing?.warnings.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _WarningCard(warnings: execution.routing!.warnings),
        ],
        const SizedBox(height: 22),
        const Text('Остановки', style: AppTypography.sectionTitle),
        const SizedBox(height: 10),
        if (execution.stops.isEmpty)
          const _EmptyStopsCard()
        else
          for (final stop in execution.stops)
            _StopCard(
              stop: stop,
              busy: _busyStopId == stop.id,
              enabled: execution.isActive,
              onComplete: () => unawaited(_completeStop(stop)),
            ),
        if (!completed && !cancelled && execution.isActive) ...[
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _finishing ? null : _completeRoute,
            icon: _finishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_rounded),
            label: const Text('Завершить маршрут'),
          ),
          const SizedBox(height: 8),
          Text(
            'Завершай остановки по мере прохождения — так история и награды будут честными.',
            textAlign: TextAlign.center,
            style: AppTypography.routeMetadata.copyWith(
              color: AppColors.secondaryInk,
            ),
          ),
        ],
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
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
      RouteExecutionStatus.completed => 'Маршрут завершён',
      RouteExecutionStatus.cancelled => 'Прохождение отменено',
    };
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.execution});

  final RouteExecution execution;

  @override
  Widget build(BuildContext context) {
    final percent = (execution.progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Прогресс', style: AppTypography.button),
                Text(
                  '$percent%',
                  style: AppTypography.button.copyWith(
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: execution.progress,
                backgroundColor: AppColors.accentBlue.withValues(alpha: .12),
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              execution.totalStops == 0
                  ? 'Остановки появятся после синхронизации маршрута'
                  : '${execution.completedStops} из ${execution.totalStops} остановок',
              style: AppTypography.routeMetadata.copyWith(
                color: AppColors.secondaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.busy,
    required this.enabled,
    required this.onComplete,
  });

  final RouteExecutionStop stop;
  final bool busy;
  final bool enabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final done = stop.isCompleted;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done
              ? AppColors.positiveSwipeTint.withValues(alpha: .14)
              : AppColors.accentBlue.withValues(alpha: .12),
          foregroundColor: done
              ? AppColors.positiveSwipeTint
              : AppColors.accentBlue,
          child: done
              ? const Icon(Icons.check_rounded)
              : Text('${stop.position}'),
        ),
        title: Text(stop.placeName, style: AppTypography.button),
        subtitle: Text(
          stop.isOptional ? 'Можно пропустить' : 'Обязательная остановка',
        ),
        trailing: done
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.positiveSwipeTint,
              )
            : FilledButton.tonal(
                onPressed: enabled && !busy ? onComplete : null,
                child: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Готово'),
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
