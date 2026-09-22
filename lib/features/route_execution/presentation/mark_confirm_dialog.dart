import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

// Colours sampled from the DESIGN-4 mockups.
const _pillInk = Color(0xFF212121);
const _pillOutline = Color(0xFFD7D7D7);
const _muted = Color(0xFF646464);
const _title = Color(0xFF212121);

/// "Are you sure?" before a stop mark that looks early. Returns true only when
/// the person confirms; closing the sheet any other way sends nothing.
///
/// Drawn as the DESIGN-4 bottom sheet (big blue icon, two pill buttons). The
/// designer drew the «too fast» case; «not there yet» reuses the same sheet
/// with the map-point icon from the same set.
Future<bool> showMarkConfirmDialog(
  BuildContext context, {
  required bool notThereYet,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    // Sized to its content: the default 9/16 height cap cut the buttons off
    // on a small phone (iPhone SE).
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _MarkConfirmSheet(notThereYet: notThereYet),
  );
  return confirmed == true;
}

class _MarkConfirmSheet extends StatelessWidget {
  const _MarkConfirmSheet({required this.notThereYet});

  final bool notThereYet;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 13, 16, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD3D3D3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ExcludeSemantics(
            child: notThereYet
                ? Image.asset(
                    AppIconography.execNotThere,
                    width: 80,
                    height: 80,
                  )
                // The raster is square around the 72×80 glyph.
                : Image.asset(
                    AppIconography.execAlarmBold,
                    width: 80,
                    height: 80,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            notThereYet
                ? 'Кажется, вы ещё не дошли\nдо этой точки. Точно отметить?'
                : 'Вы слишком быстро\nдошли до точки. Вы точно на месте?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: _title,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Это важно для правильного распределения очков ТП\n'
            'и начисления достижений',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: _muted,
            ),
          ),
          const SizedBox(height: 16),
          _PillButton(
            label: 'Отметить точку',
            filled: true,
            height: 56,
            fontSize: 18,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          _PillButton(
            label: 'Не отмечать',
            filled: false,
            height: 56,
            fontSize: 18,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
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

/// How far above the screen bottom the route card's «Пройти маршрут» button
/// ends: the shell's detail bar (CTA over the collapsed nav) is 126 pt tall
/// and floats [_shellBarBottomGap] above the safe area.
const _shellDetailBarHeight = 126.0;
const _shellBarBottomGap = 8.0;

/// Explanation shown once before the system location prompt. True = allow.
///
/// DESIGN-4: a white card floating right above the «Пройти маршрут» button of
/// the route card, not a centred system-style dialog.
Future<bool> showLocationExplanationDialog(BuildContext context) async {
  final allow = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Не сейчас',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => const _LocationExplanationCard(),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
  return allow == true;
}

class _LocationExplanationCard extends StatelessWidget {
  const _LocationExplanationCard();

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barBottom = safeBottom > 0 ? safeBottom : _shellBarBottomGap;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          barBottom + _shellDetailBarHeight + 24,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Разрешить геолокацию',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Покажем расстояние до точки и поможем точнее\n'
                    'засчитывать прохождение. Необязательно',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PillButton(
                    label: 'Разрешить',
                    filled: true,
                    height: 44,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 8),
                  _PillButton(
                    label: 'Не сейчас',
                    filled: false,
                    height: 44,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context).pop(false),
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

/// Black filled or white outlined pill, as on the DESIGN-4 sheets.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.height,
    required this.fontSize,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final double height;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? _pillInk : Colors.white,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: _pillOutline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: filled ? Colors.white : AppColors.primaryInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
