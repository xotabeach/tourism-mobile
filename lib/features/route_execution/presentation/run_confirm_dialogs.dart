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
