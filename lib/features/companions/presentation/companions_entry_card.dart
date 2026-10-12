import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
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
      if (mounted) {
        showAppNotice(
          context,
          companionErrorText(error),
          kind: AppNoticeKind.error,
        );
      }
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
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlatPalette.paper,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 74,
                height: 64,
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _TwoBeans()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Пройти вместе',
                      style: TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: FlatPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      here == null
                          ? 'Соберите друзей у костра: каждый отмечает точки '
                                'сам, а в группе видно, кто где'
                          : here.isInvitation
                          ? '${here.organizerName} зовёт вас на этот маршрут'
                          : 'Ваша группа уже собирается',
                      style: AppTypography.settingsRowSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (here != null)
            _FlatButton(
              label: here.isInvitation ? 'Посмотреть приглашение' : 'К группе',
              onPressed: () => _open(here),
            )
          else ...[
            // One under the other: side by side the labels were cut on a
            // phone-wide screen.
            _FlatButton(
              label: 'Собрать группу',
              onPressed: _busy ? null : _create,
            ),
            const SizedBox(height: 8),
            _FlatButton(
              label: 'У меня есть код',
              secondary: true,
              onPressed: _code,
            ),
          ],
        ],
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  const _FlatButton({
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
      backgroundColor: secondary ? FlatPalette.white : FlatPalette.flameOuter,
      foregroundColor: secondary ? FlatPalette.ink : FlatPalette.white,
      minimumSize: const Size.fromHeight(46),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _TwoBeans extends CustomPainter {
  const _TwoBeans();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    paintBean(
      canvas,
      Offset(size.width * 0.32, h),
      h * 0.86,
      FlatPalette.beans[1],
      const BeanPose(
        lookX: 1,
        look: BeanLook(
          shape: BeanShape.pinWide,
          pattern: BeanPattern.belly,
          extra: BeanExtra.backpack,
          accessory: BeanHat.cap,
        ),
      ),
    );
    paintBean(
      canvas,
      Offset(size.width * 0.72, h),
      h * 0.74,
      FlatPalette.beans[2],
      const BeanPose(
        lookX: -1,
        happy: true,
        wave: 0.9,
        look: BeanLook(
          shape: BeanShape.pinTall,
          pattern: BeanPattern.spots,
          extra: BeanExtra.scarf,
          accessory: BeanHat.beanie,
        ),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _TwoBeans oldDelegate) => false;
}
