import 'package:flutter/material.dart';

/// "Are you sure?" before a stop mark that looks early. Returns true only when
/// the person confirms; closing the dialog any other way sends nothing.
Future<bool> showMarkConfirmDialog(
  BuildContext context, {
  required bool notThereYet,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        notThereYet
            ? 'Кажется, вы ещё не дошли до этой точки'
            : 'Быстрее, чем обычно',
      ),
      content: Text(
        notThereYet
            ? 'Точно отметить?'
            : 'Этот участок пройден заметно быстрее расчётного времени. '
                  'Вы точно дошли до точки?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(notThereYet ? 'Отмена' : 'Отменить отметку'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(notThereYet ? 'Всё равно отметить' : 'Да, дошёл(ла)'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// "Take the mark back?" before unmarking the latest stop (FRONTEND-36).
Future<bool> showUnmarkConfirmDialog(
  BuildContext context, {
  required String placeName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Снять отметку?'),
      content: Text('Точка «$placeName» снова станет неотмеченной.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Снять отметку'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Explanation shown once before the system location prompt. True = allow.
Future<bool> showLocationExplanationDialog(BuildContext context) async {
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Разрешить геолокацию?'),
      content: const Text(
        'Покажем расстояние до точки и поможем точнее засчитывать '
        'прохождение. Это необязательно.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Не сейчас'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Разрешить'),
        ),
      ],
    ),
  );
  return allow == true;
}
