import 'package:flutter/material.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/features/route_execution/presentation/widgets/execution_chrome.dart';

const _footnoteStyle = TextStyle(
  fontFamily: AppFonts.rubik,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.3,
  color: ExecutionColors.muted,
);

/// The buttons under the stop list: what a run in its current state allows.
///
/// Rows of the screen's list rather than one widget, so each keeps its own
/// place in the list and its own semantics.
List<Widget> executionActions({
  required RouteExecution execution,
  required bool finishing,
  required VoidCallback onResume,
  required VoidCallback onCancel,
  required VoidCallback onFinishEarly,
  required VoidCallback onComplete,
  required VoidCallback onEndDay,
}) {
  return [
    if (execution.status == RouteExecutionStatus.paused &&
        execution.nightPaused) ...[
      const SizedBox(height: 18),
      ExecutionDarkButton(
        label: 'Продолжить: день ${execution.currentDay}',
        onPressed: onResume,
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: onFinishEarly,
          child: const Text('Завершить многодневный маршрут'),
        ),
      ),
      const Text(
        'Отдых до следующего дня. Отметки недоступны, пока не продолжишь.',
        textAlign: TextAlign.center,
        style: _footnoteStyle,
      ),
    ] else if (execution.status == RouteExecutionStatus.paused) ...[
      const SizedBox(height: 18),
      ExecutionDarkButton(label: 'Возобновить', onPressed: onResume),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: onCancel,
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
      ExecutionDarkButton(
        label: 'Завершить маршрут',
        busy: finishing,
        onPressed: finishing ? null : onComplete,
      ),
      if (execution.plannedDays > 1) ...[
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: onEndDay,
            child: Text('Закончить день ${execution.currentDay}'),
          ),
        ),
      ],
      const SizedBox(height: 8),
      const Text(
        'Завершай остановки по мере прохождения для верного отображения истории и наград',
        textAlign: TextAlign.center,
        style: _footnoteStyle,
      ),
    ],
  ];
}
