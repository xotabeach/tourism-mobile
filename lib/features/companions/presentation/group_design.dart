import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/bean_head.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/features/companions/presentation/group_qr.dart';
import 'package:tourism_mobile/features/routes/application/routes_providers.dart';

/// The pieces of the designer's group screens (FRONTEND-88, FRONTEND-89,
/// mockups of 2026-10-18), measured on the mockups at 375 points wide.
abstract final class GroupDesign {
  static const blue = Color(0xFF1D71CB);
  static const codeFill = Color(0xFFEDF4FC);
  static const dark = Color(0xFF212121);
  static const dangerFill = Color(0xFFFAE6E7);
  static const dangerBorder = Color(0xFFDB4C4D);
  static const danger = Color(0xFFDB4C4D);
  static const outline = Color(0xFFE3E3E5);
  static const organizer = Color(0xFF7FB0E8);
}

/// «Группа в пути:», «Совместный маршрут:», «Попутчики:».
class GroupTitle extends StatelessWidget {
  const GroupTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: 19.5,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.primaryInk,
    ),
  );
}

/// The route the group walks: cover, name, author, a chevron to open it.
class GroupRouteCard extends ConsumerWidget {
  const GroupRouteCard({
    required this.routeId,
    required this.name,
    required this.coverUrl,
    required this.onTap,
    super.key,
  });

  final String routeId;
  final String name;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final author =
        ref.watch(routeDetailProvider(routeId)).valueOrNull?.authorLabel ??
        'КрымТрип редакция';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: GroupDesign.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox.square(
                    dimension: 45,
                    child: AppImages.coverImage(
                      config: config,
                      coverImageUrl: coverUrl,
                      fallbackSeed: routeId,
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 12,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: AppColors.primaryInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The black stadium button: «Готов», «Начать прохождение».
class GroupDarkButton extends StatelessWidget {
  const GroupDarkButton({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: GroupDesign.dark,
      foregroundColor: Colors.white,
      disabledBackgroundColor: GroupDesign.dark.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white,
      minimumSize: const Size.fromHeight(42),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 15,
        fontWeight: FontWeight.w300,
      ),
    ),
    child: Text(label),
  );
}

/// The pink stadium button: «Покинуть группу», «Сойти с дистанции».
class GroupDangerButton extends StatelessWidget {
  const GroupDangerButton({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: GroupDesign.dangerFill,
      foregroundColor: GroupDesign.danger,
      minimumSize: const Size.fromHeight(43),
      shape: const StadiumBorder(),
      side: const BorderSide(color: GroupDesign.dangerBorder, width: 0.8),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 14.5,
        fontWeight: FontWeight.w300,
      ),
    ),
    child: Text(label),
  );
}

/// A plain outlined stadium button for the rarer actions.
class GroupOutlineButton extends StatelessWidget {
  const GroupOutlineButton({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryInk,
      minimumSize: const Size.fromHeight(42),
      shape: const StadiumBorder(),
      side: const BorderSide(color: GroupDesign.outline),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    child: Text(label),
  );
}

/// A member: their character's head, name (and «Организатор»), a line
/// under it and a chevron. The head is 48, a little under the mockup's
/// 61 (owner, 2026-10-18).
class GroupMemberRow extends StatelessWidget {
  const GroupMemberRow({
    required this.kind,
    required this.name,
    required this.subtitle,
    this.organizer = false,
    this.faded = false,
    this.onTap,
    this.trailing,
    super.key,
  });

  final BeanKind kind;
  final String name;
  final String subtitle;
  final bool organizer;
  final bool faded;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: faded ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            BeanHead(kind: kind, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: name,
                      children: [
                        if (organizer)
                          const TextSpan(
                            text: '  Организатор',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: GroupDesign.organizer,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 13,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: AppColors.primaryInk,
                ),
          ],
        ),
      ),
    ),
  );
}

/// «Всего в пути: 174 мин.», «До след. точки: 57,1 км».
class GroupStatRow extends StatelessWidget {
  const GroupStatRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GroupDesign.outline),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: GroupDesign.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 12.5,
              fontWeight: FontWeight.w300,
              color: AppColors.secondaryInk,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryInk,
          ),
        ),
      ],
    ),
  );
}

/// «Код группы:» with the code, copy and share, beside the green character
/// holding the group's QR.
class GroupCodeBlock extends StatelessWidget {
  const GroupCodeBlock({
    required this.code,
    required this.routeName,
    super.key,
  });

  final String code;
  final String routeName;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) showAppNotice(context, 'Код скопирован');
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(
      text:
          'Пойдём вместе по маршруту «$routeName» в КрымТрипе. Код группы: '
          '$code',
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = width * 237 / 343;
      final side = width - cardWidth - 12;
      return SizedBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: cardWidth,
              padding: const EdgeInsets.fromLTRB(13, 14, 12, 12),
              decoration: BoxDecoration(
                color: GroupDesign.codeFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GroupDesign.blue, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Код группы:',
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Покажите код или QR тому, кто хочет пройти маршрут '
                    'совместно',
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 11.5,
                      height: 1.15,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const Divider(height: 14, color: Color(0xFFCADBEF)),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontFamily: AppFonts.rubik,
                              fontSize: 38,
                              height: 1.05,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                              color: GroupDesign.blue,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Скопировать код',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        onPressed: () => unawaited(_copy(context)),
                        icon: const Icon(
                          Icons.filter_none_rounded,
                          size: 22,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 10, color: Color(0xFFCADBEF)),
                  SizedBox(
                    height: 33,
                    child: FilledButton(
                      onPressed: () => unawaited(_share()),
                      style: FilledButton.styleFrom(
                        backgroundColor: GroupDesign.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      child: const Text('Поделиться кодом'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: side,
              height: 184,
              child: GestureDetector(
                key: const ValueKey('group-qr'),
                onTap: () => unawaited(showGroupQrSheet(context, code)),
                child: _QrHolder(code: code),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The green character holding the QR in front of it, as on the mockup.
class _QrHolder extends StatelessWidget {
  const _QrHolder({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final qr = w;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _HolderPainter())),
          // Hands peeking out from behind the QR's sides, as drawn.
          for (final left in [-qr * 0.04, qr * 0.92])
            Positioned(
              left: left,
              top: 69 + qr * 0.19,
              width: qr * 0.12,
              height: qr * 0.14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BeanKind.tall.art.data.bodyTop,
                  borderRadius: BorderRadius.circular(qr * 0.04),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: 69,
            width: qr,
            height: qr,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GroupDesign.dark, width: 1.4),
              ),
              child: GroupQrImage(code: code, size: qr - 13, quiet: 0),
            ),
          ),
        ],
      );
    },
  );
}

class _HolderPainter extends CustomPainter {
  const _HolderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const look = BeanLook(kind: BeanKind.tall);
    // Feet at the bottom, the head's top at the top: the green build is
    // 553 of the blue one's 404 tall.
    final height = (size.height - 4) * 404 / 553;
    paintBean(
      canvas,
      Offset(size.width / 2, size.height - 4),
      height,
      look.color,
      const BeanPose(look: look, armless: true),
    );
  }

  @override
  bool shouldRepaint(covariant _HolderPainter oldDelegate) => false;
}

/// «57,1 км», «800 м».
String formatDistance(int meters) {
  if (meters < 1000) return '$meters м';
  final km = meters / 1000;
  final text = km >= 100 ? km.round().toString() : km.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} км';
}
