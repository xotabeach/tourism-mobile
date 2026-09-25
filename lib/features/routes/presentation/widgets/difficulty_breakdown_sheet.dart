import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart'
    show routeDifficultyLabel;

const _muted = Color(0xFF646464);

/// Why a route is as hard as it says (spec 17, section 8): the estimate's
/// reasons, whose rating is shown, and «примерно» when data is thin.
Future<void> showDifficultyBreakdownSheet(
  BuildContext context, {
  required RouteDetail route,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DifficultyBreakdownSheet(route: route),
  );
}

/// Who set the shown number, when it is not the estimate.
String? difficultySourceNote(RouteSummary route) {
  final estimate = route.difficultyAuto;
  if (route.difficultySource == 'auto' || estimate == null) return null;
  if (estimate == route.shownDifficulty) return null;
  final who = route.difficultySource == 'author'
      ? 'По оценке автора'
      : 'По оценке редакции';
  return '$who, по расчёту: $estimate из 5';
}

class DifficultyBreakdownSheet extends StatelessWidget {
  const DifficultyBreakdownSheet({required this.route, super.key});

  final RouteDetail route;

  @override
  Widget build(BuildContext context) {
    final level = route.shownDifficulty;
    final breakdown = route.difficultyBreakdown;
    final lines = [
      for (final reason in breakdown?.reasons ?? const <DifficultyReason>[])
        if (reason.code != 'low_data') ?reason.text,
    ];
    final note = difficultySourceNote(route);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        13,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 66,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD3D3D3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Сложность: $level из 5 · ${routeDifficultyLabel(level)}',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.primaryInk,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: _small),
          ],
          const SizedBox(height: 14),
          if (lines.isEmpty)
            const Text(
              'Подробного расчёта для этого маршрута пока нет.',
              style: _body,
            )
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 10),
                      child: Icon(Icons.circle, size: 6, color: _muted),
                    ),
                    Expanded(child: Text(line, style: _body)),
                  ],
                ),
              ),
          if (breakdown?.approximate ?? false) ...[
            const SizedBox(height: 6),
            const Text(
              'Оценка примерная: о рельефе и тропах мало данных.',
              style: _small,
            ),
          ],
        ],
      ),
    );
  }
}

const _body = TextStyle(
  fontFamily: AppFonts.rubik,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.3,
  color: AppColors.primaryInk,
);

const _small = TextStyle(
  fontFamily: AppFonts.rubik,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.3,
  color: _muted,
);
