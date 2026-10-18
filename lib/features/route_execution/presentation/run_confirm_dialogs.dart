import 'package:flutter/material.dart';

/// «Остановить прохождение?» before a run is cancelled.
Future<bool> showCancelRunDialog(BuildContext context) async {
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
  return confirmed ?? false;
}

/// «Завершить маршрут досрочно?» before a multi-day run is ended early.
Future<bool> showFinishEarlyDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Завершить маршрут досрочно?'),
      content: const Text(
        'Очки начислятся за дни, пройденные полностью. '
        'Маршрут не будет считаться пройденным.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Остаться'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Завершить'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// What «Завершить маршрут» asks when some stops are still open
/// (FRONTEND-91): they will be counted as not reached.
Future<bool> showFinishWithOpenStopsDialog(
  BuildContext context, {
  required int marked,
  required int total,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Завершить маршрут?'),
      content: Text(
        'Отмечено $marked из $total. Остальные точки засчитаем как '
        'непройденные. Очки за отмеченные точки сохранятся, а маршрут '
        'засчитается пройденным, только если отмечено достаточно точек.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Продолжить путь'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Завершить'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// «Завершить маршрут» with nothing marked: a run without a single stop
/// reached can only be called off (FRONTEND-91).
Future<bool> showNothingMarkedDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ни одна точка не отмечена'),
      content: const Text(
        'Завершить можно маршрут, на котором отмечена хотя бы одна точка. '
        'Если передумали идти, прохождение можно отменить.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Остаться'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Отменить прохождение'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
