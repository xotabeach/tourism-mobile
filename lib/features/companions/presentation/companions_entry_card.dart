import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// «Пройти вместе» on a published route's page (spec 11b): gather friends,
/// come in with a code, or open the group already gathering for it.
class CompanionsEntryCard extends ConsumerStatefulWidget {
  const CompanionsEntryCard({required this.routeId, super.key});

  final String routeId;

  @override
  ConsumerState<CompanionsEntryCard> createState() =>
      _CompanionsEntryCardState();
}

class _CompanionsEntryCardState extends ConsumerState<CompanionsEntryCard> {
  var _busy = false;

  void _open(CompanionGroup group) => unawaited(
    context.pushNamed(
      AppRouteNames.companionGroup,
      pathParameters: {'groupId': group.id},
    ),
  );

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final group = await ref
          .read(companionsRepositoryProvider)
          .create(widget.routeId);
      ref.invalidate(myCompanionGroupsProvider);
      if (mounted) _open(group);
    } on Object catch (error) {
      if (mounted) await showCompanionError(context, ref, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _code() async {
    final group = await showJoinCodeSheet(context);
    if (group != null && mounted) {
      ref.invalidate(myCompanionGroupsProvider);
      _open(group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myCompanionGroupsProvider).valueOrNull ?? const [];
    final here = mine
        .where((g) => g.routeId == widget.routeId && g.status.isLive)
        .firstOrNull;
    // The designer's card (FRONTEND-87): text and buttons on the left, the
    // four characters on the right, cut by the card's edge.
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth * 0.63;
        return Container(
          width: constraints.maxWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _blue, width: 2),
          ),
          child: Stack(
            children: [
              Positioned(
                left: textWidth,
                right: 0,
                top: 6,
                bottom: 0,
                child: const ExcludeSemantics(
                  child: CustomPaint(painter: _FourBeans()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 9, 0, 8),
                child: SizedBox(
                  width: textWidth - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Пройдите маршрут вместе:',
                        style: TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: AppColors.primaryInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        here == null
                            ? 'Каждый отмечает точки сам, а в группе видно, '
                                  'кто сколько прошел'
                            : here.isInvitation
                            ? '${here.organizerName} зовёт вас на этот маршрут'
                            : 'Ваша группа уже собирается',
                        style: const TextStyle(
                          fontFamily: AppFonts.rubik,
                          fontSize: 11.5,
                          height: 1.25,
                          color: AppColors.secondaryInk,
                        ),
                      ),
                      const SizedBox(height: 17),
                      if (here != null)
                        _CardButton(
                          label: here.isInvitation
                              ? 'Посмотреть приглашение'
                              : 'К группе',
                          onPressed: () => _open(here),
                        )
                      else ...[
                        _CardButton(
                          label: 'Создать лобби',
                          onPressed: _busy ? null : _create,
                        ),
                        const SizedBox(height: 5),
                        _CardButton(
                          label: 'У меня есть код',
                          secondary: true,
                          onPressed: _code,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _blue = Color(0xFF1D71CB);
const _cardFill = Color(0xFFE8F0FA);

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: secondary ? Colors.white : _blue,
      foregroundColor: secondary ? _blue : Colors.white,
      disabledBackgroundColor: secondary
          ? Colors.white
          : _blue.withValues(alpha: 0.6),
      minimumSize: const Size.fromHeight(36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: secondary ? const BorderSide(color: _blue) : BorderSide.none,
      ),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 14,
        fontWeight: FontWeight.w300,
      ),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

/// The four characters of the card: the green and the red behind, the
/// blue one in a flat cap between them, the yellow in a straw hat in front,
/// arms wide, cut by the card's bottom edge.
class _FourBeans extends CustomPainter {
  const _FourBeans();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Placed as on the designer's card: the feet below its edge.
    void bean(
      double x,
      double feetY,
      double height,
      BeanKind kind, {
      BeanHat? hat,
      BeanKind? shape,
      double face = 1,
      double lookX = 0,
      double cheer = 0,
      BeanMood mood = BeanMood.smile,
      bool eyesAhead = false,
      bool stickToRight = true,
    }) => paintBean(
      canvas,
      Offset(w * x, h * feetY),
      h * height,
      kind.color,
      BeanPose(
        lookX: lookX,
        cheer: cheer,
        mood: mood,
        eyesAhead: eyesAhead,
        face: face,
        stickToRight: stickToRight,
        look: BeanLook(kind: kind, accessory: hat, shape: shape),
      ),
    );

    bean(0.51, 0.34, 0.34, BeanKind.pin, hat: BeanHat.flatCap, lookX: 0.3);
    bean(0.25, 0.61, 0.49, BeanKind.tall, lookX: 0.4);
    bean(
      0.73,
      0.55,
      0.475,
      BeanKind.round,
      mood: BeanMood.cross,
      eyesAhead: true,
      stickToRight: false,
    );
    bean(
      0.47,
      1.31,
      0.81,
      BeanKind.small,
      shape: BeanKind.tall,
      face: 1.3,
      hat: BeanHat.strawHat,
      cheer: 1,
      mood: BeanMood.beam,
      eyesAhead: true,
    );
  }

  @override
  bool shouldRepaint(covariant _FourBeans oldDelegate) => false;
}
