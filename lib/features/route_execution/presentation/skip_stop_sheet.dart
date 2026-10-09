import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';

const _pillOutline = Color(0xFFD7D7D7);
const _muted = Color(0xFF646464);

/// «Пропустить точку?»: the reason is the answer, picked in one tap.
/// Returns null when the sheet is closed any other way, and nothing is sent.
Future<StopSkipReason?> showSkipStopSheet(
  BuildContext context, {
  required String placeName,
}) {
  return showModalBottomSheet<StopSkipReason>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SkipStopSheet(placeName: placeName),
  );
}

class _SkipStopSheet extends StatelessWidget {
  const _SkipStopSheet({required this.placeName});

  final String placeName;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 13, 16, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            'Пропустить «$placeName»?',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.primaryInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Выбери причину. Очки начислятся за пройденные участки, '
            'пропуск можно отменить до завершения маршрута.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: _muted,
            ),
          ),
          const SizedBox(height: 16),
          for (final reason in StopSkipReason.values) ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(reason),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.primaryInk,
                side: const BorderSide(color: _pillOutline),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(reason.label),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
