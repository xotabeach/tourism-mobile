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
import 'package:tourism_mobile/features/companions/presentation/flat/hat_art.dart';
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

    bean(0.495, 0.42, 0.384, BeanKind.pin, hat: BeanHat.flatCap, lookX: 0.3);
    bean(0.25, 0.651, 0.49, BeanKind.tall, lookX: 0.4);
    bean(
      0.721,
      0.619,
      0.499,
      BeanKind.round,
      mood: BeanMood.cross,
      eyesAhead: true,
      stickToRight: false,
    );
    _paintCardYellow(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FourBeans oldDelegate) => false;
}

// The yellow one of the card, laid out by the designer's mockup
// (FRONTEND-87, owner 2026-10-16: «пиксель в пиксель»). Everything is in
// the mockup's pixels, where the card is 825 wide with its top-left corner
// at (37, 983); the painter starts at 63% of the card's width, 6 below its
// top. The outline, the smile and the arms were traced from the mockup;
// the eyes, the shine and the hat are its measured sizes.
void _paintCardYellow(Canvas canvas, Size size) {
  // The painter sits inside the card's 2-wide border, from 63% of the
  // card's width and 6 below the border's inner edge.
  final cardWidth = (size.width + 4) / 0.37;
  final u = cardWidth / 825;
  canvas.save();
  canvas.translate(-(556.75 * u + 2), -(983 * u + 8));
  canvas.scale(u);

  final arm = Paint()
    ..color = const Color(0xFFDCBC1A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 11.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(
    Path()
      ..moveTo(640, 1262)
      ..quadraticBezierTo(600, 1243, 574, 1223),
    arm,
  );
  canvas.drawPath(
    Path()
      ..moveTo(756, 1262)
      ..quadraticBezierTo(797, 1243, 823, 1224),
    arm,
  );

  final body = Path()..addPolygon(_yellowBody, true);
  canvas.drawPath(
    body,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDCB2C), Color(0xFFF3C226)],
      ).createShader(const Rect.fromLTRB(600, 1110, 800, 1340)),
  );
  // The light streak down the top left.
  canvas.save();
  canvas.clipPath(body);
  canvas.drawPath(
    Path()
      ..moveTo(632, 1132)
      ..quadraticBezierTo(612, 1150, 611, 1186)
      ..lineTo(622, 1186)
      ..quadraticBezierTo(621, 1158, 640, 1138)
      ..close(),
    Paint()
      ..color = const Color(0xFFF4D94C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
  );
  canvas.restore();

  for (final x in const [671.0, 724.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 1179.5), width: 24, height: 45),
      Paint()..color = Colors.black,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + 1, 1172), width: 7, height: 13),
      Paint()..color = Colors.white,
    );
  }
  canvas.drawPath(
    Path()..addPolygon(_yellowMouth, true),
    Paint()..color = Colors.white,
  );

  paintHatArtIn(
    canvas,
    BeanHat.strawHat,
    const Rect.fromLTWH(612.5, 1066, 173, 73),
  );
  canvas.restore();
}

const _yellowBody = <Offset>[
  Offset(700.0, 1112.0),
  Offset(677.5, 1123.5),
  Offset(660.5, 1125.5),
  Offset(650.5, 1127.5),
  Offset(643.5, 1129.5),
  Offset(638.5, 1131.5),
  Offset(634.5, 1133.5),
  Offset(631.5, 1135.5),
  Offset(629.5, 1137.5),
  Offset(627.5, 1139.5),
  Offset(626.5, 1141.5),
  Offset(625.5, 1143.5),
  Offset(624.5, 1145.5),
  Offset(622.5, 1147.5),
  Offset(621.5, 1149.5),
  Offset(620.5, 1151.5),
  Offset(619.5, 1153.5),
  Offset(618.5, 1155.5),
  Offset(617.5, 1157.5),
  Offset(616.5, 1159.5),
  Offset(616.5, 1161.5),
  Offset(614.5, 1163.5),
  Offset(614.5, 1165.5),
  Offset(613.5, 1167.5),
  Offset(612.5, 1169.5),
  Offset(611.5, 1171.5),
  Offset(611.5, 1173.5),
  Offset(611.5, 1175.5),
  Offset(611.5, 1177.5),
  Offset(610.5, 1179.5),
  Offset(610.5, 1181.5),
  Offset(609.5, 1183.5),
  Offset(609.5, 1185.5),
  Offset(609.5, 1187.5),
  Offset(609.5, 1189.5),
  Offset(609.5, 1191.5),
  Offset(609.5, 1193.5),
  Offset(609.5, 1195.5),
  Offset(609.5, 1197.5),
  Offset(609.5, 1199.5),
  Offset(610.5, 1201.5),
  Offset(610.5, 1203.5),
  Offset(610.5, 1205.5),
  Offset(610.5, 1207.5),
  Offset(611.5, 1209.5),
  Offset(611.5, 1211.5),
  Offset(612.5, 1213.5),
  Offset(612.5, 1215.5),
  Offset(613.5, 1217.5),
  Offset(613.5, 1219.5),
  Offset(614.5, 1221.5),
  Offset(614.5, 1223.5),
  Offset(614.5, 1225.5),
  Offset(615.5, 1227.5),
  Offset(616.5, 1229.5),
  Offset(616.5, 1231.5),
  Offset(617.5, 1233.5),
  Offset(618.5, 1235.5),
  Offset(618.5, 1237.5),
  Offset(619.5, 1239.5),
  Offset(619.5, 1241.5),
  Offset(620.5, 1243.5),
  Offset(620.5, 1245.5),
  Offset(621.5, 1247.5),
  Offset(622.5, 1249.5),
  Offset(623.5, 1251.5),
  Offset(624.5, 1253.5),
  Offset(625.5, 1255.5),
  Offset(625.5, 1257.5),
  Offset(627.5, 1259.5),
  Offset(627.5, 1261.5),
  Offset(629.5, 1263.5),
  Offset(630.5, 1265.5),
  Offset(631.5, 1267.5),
  Offset(632.5, 1269.5),
  Offset(634.5, 1271.5),
  Offset(634.5, 1273.5),
  Offset(636.5, 1275.5),
  Offset(637.5, 1277.5),
  Offset(637.5, 1279.5),
  Offset(639.5, 1281.5),
  Offset(640.5, 1283.5),
  Offset(641.5, 1285.5),
  Offset(642.5, 1287.5),
  Offset(644.5, 1289.5),
  Offset(645.5, 1291.5),
  Offset(646.5, 1293.5),
  Offset(647.5, 1295.5),
  Offset(648.5, 1297.5),
  Offset(650.5, 1299.5),
  Offset(651.5, 1301.5),
  Offset(652.5, 1303.5),
  Offset(653.5, 1305.5),
  Offset(655.5, 1307.5),
  Offset(656.5, 1309.5),
  Offset(658.5, 1311.5),
  Offset(659.5, 1313.5),
  Offset(660.5, 1315.5),
  Offset(662.5, 1317.5),
  Offset(663.5, 1319.5),
  Offset(663.5, 1321.5),
  Offset(665.5, 1323.5),
  Offset(666.5, 1325.5),
  Offset(671.8, 1334.0),
  Offset(676.6, 1342.0),
  Offset(681.4, 1350.0),
  Offset(712.6, 1350.0),
  Offset(717.4, 1342.0),
  Offset(722.2, 1334.0),
  Offset(728.5, 1325.5),
  Offset(729.5, 1323.5),
  Offset(731.5, 1321.5),
  Offset(732.5, 1319.5),
  Offset(732.5, 1317.5),
  Offset(734.5, 1315.5),
  Offset(735.5, 1313.5),
  Offset(737.5, 1311.5),
  Offset(738.5, 1309.5),
  Offset(739.5, 1307.5),
  Offset(741.5, 1305.5),
  Offset(742.5, 1303.5),
  Offset(743.5, 1301.5),
  Offset(745.5, 1299.5),
  Offset(746.5, 1297.5),
  Offset(747.5, 1295.5),
  Offset(748.5, 1293.5),
  Offset(750.5, 1291.5),
  Offset(751.5, 1289.5),
  Offset(752.5, 1287.5),
  Offset(753.5, 1285.5),
  Offset(754.5, 1283.5),
  Offset(755.5, 1281.5),
  Offset(757.5, 1279.5),
  Offset(758.5, 1277.5),
  Offset(759.5, 1275.5),
  Offset(760.5, 1273.5),
  Offset(761.5, 1271.5),
  Offset(762.5, 1269.5),
  Offset(763.5, 1267.5),
  Offset(764.5, 1265.5),
  Offset(765.5, 1263.5),
  Offset(766.5, 1261.5),
  Offset(767.5, 1259.5),
  Offset(768.5, 1257.5),
  Offset(770.5, 1255.5),
  Offset(771.5, 1253.5),
  Offset(772.5, 1251.5),
  Offset(773.5, 1249.5),
  Offset(773.5, 1247.5),
  Offset(774.5, 1245.5),
  Offset(775.5, 1243.5),
  Offset(776.5, 1241.5),
  Offset(777.5, 1239.5),
  Offset(776.5, 1237.5),
  Offset(777.5, 1235.5),
  Offset(778.5, 1233.5),
  Offset(778.5, 1231.5),
  Offset(779.5, 1229.5),
  Offset(780.5, 1227.5),
  Offset(780.5, 1225.5),
  Offset(781.5, 1223.5),
  Offset(781.5, 1221.5),
  Offset(782.5, 1219.5),
  Offset(782.5, 1217.5),
  Offset(783.5, 1215.5),
  Offset(783.5, 1213.5),
  Offset(784.5, 1211.5),
  Offset(785.5, 1209.5),
  Offset(785.5, 1207.5),
  Offset(785.5, 1205.5),
  Offset(786.5, 1203.5),
  Offset(786.5, 1201.5),
  Offset(786.5, 1199.5),
  Offset(786.5, 1197.5),
  Offset(785.5, 1195.5),
  Offset(785.5, 1193.5),
  Offset(786.5, 1191.5),
  Offset(786.5, 1189.5),
  Offset(786.5, 1187.5),
  Offset(786.5, 1185.5),
  Offset(786.5, 1183.5),
  Offset(785.5, 1181.5),
  Offset(785.5, 1179.5),
  Offset(785.5, 1177.5),
  Offset(785.5, 1175.5),
  Offset(784.5, 1173.5),
  Offset(784.5, 1171.5),
  Offset(784.5, 1169.5),
  Offset(783.5, 1167.5),
  Offset(782.5, 1165.5),
  Offset(782.5, 1163.5),
  Offset(781.5, 1161.5),
  Offset(780.5, 1159.5),
  Offset(780.5, 1157.5),
  Offset(779.5, 1155.5),
  Offset(778.5, 1153.5),
  Offset(777.5, 1151.5),
  Offset(776.5, 1149.5),
  Offset(775.5, 1147.5),
  Offset(774.5, 1145.5),
  Offset(773.5, 1143.5),
  Offset(772.5, 1141.5),
  Offset(771.5, 1139.5),
  Offset(769.5, 1137.5),
  Offset(766.5, 1135.5),
  Offset(763.5, 1133.5),
  Offset(759.5, 1131.5),
  Offset(754.5, 1129.5),
  Offset(748.5, 1127.5),
  Offset(740.5, 1125.5),
  Offset(723.5, 1123.5),
];

const _yellowMouth = <Offset>[
  Offset(670.5, 1216.1),
  Offset(671.5, 1214.2),
  Offset(672.5, 1213.5),
  Offset(673.5, 1213.4),
  Offset(674.5, 1213.5),
  Offset(675.5, 1213.8),
  Offset(676.5, 1214.1),
  Offset(677.5, 1214.5),
  Offset(678.5, 1215.0),
  Offset(679.5, 1215.2),
  Offset(680.5, 1215.9),
  Offset(681.5, 1216.2),
  Offset(682.5, 1216.7),
  Offset(683.5, 1217.0),
  Offset(684.5, 1217.5),
  Offset(685.5, 1217.9),
  Offset(686.5, 1218.2),
  Offset(687.5, 1218.5),
  Offset(688.5, 1218.9),
  Offset(689.5, 1219.2),
  Offset(690.5, 1219.5),
  Offset(691.5, 1219.8),
  Offset(692.5, 1220.0),
  Offset(693.5, 1220.1),
  Offset(694.5, 1220.1),
  Offset(695.5, 1220.2),
  Offset(696.5, 1220.2),
  Offset(697.5, 1220.2),
  Offset(698.5, 1220.2),
  Offset(699.5, 1220.1),
  Offset(700.5, 1220.1),
  Offset(701.5, 1220.0),
  Offset(702.5, 1220.0),
  Offset(703.5, 1219.8),
  Offset(704.5, 1219.6),
  Offset(705.5, 1219.4),
  Offset(706.5, 1219.2),
  Offset(707.5, 1218.9),
  Offset(708.5, 1218.6),
  Offset(709.5, 1218.3),
  Offset(710.5, 1218.0),
  Offset(711.5, 1217.7),
  Offset(712.5, 1217.2),
  Offset(713.5, 1216.9),
  Offset(714.5, 1216.4),
  Offset(715.5, 1216.0),
  Offset(716.5, 1215.5),
  Offset(717.5, 1215.0),
  Offset(718.5, 1214.5),
  Offset(719.5, 1214.0),
  Offset(720.5, 1213.4),
  Offset(721.5, 1213.2),
  Offset(722.5, 1213.0),
  Offset(723.5, 1213.0),
  Offset(724.5, 1213.6),
  Offset(724.5, 1222.1),
  Offset(723.5, 1224.9),
  Offset(722.5, 1227.0),
  Offset(721.5, 1228.9),
  Offset(720.5, 1230.1),
  Offset(719.5, 1231.8),
  Offset(718.5, 1232.8),
  Offset(717.5, 1233.8),
  Offset(716.5, 1234.8),
  Offset(715.5, 1235.8),
  Offset(714.5, 1236.7),
  Offset(713.5, 1237.4),
  Offset(712.5, 1238.1),
  Offset(711.5, 1238.8),
  Offset(710.5, 1239.6),
  Offset(709.5, 1240.0),
  Offset(708.5, 1240.4),
  Offset(707.5, 1240.9),
  Offset(706.5, 1241.5),
  Offset(705.5, 1241.8),
  Offset(704.5, 1242.1),
  Offset(703.5, 1242.5),
  Offset(702.5, 1242.8),
  Offset(701.5, 1243.0),
  Offset(700.5, 1243.1),
  Offset(699.5, 1243.2),
  Offset(698.5, 1243.2),
  Offset(697.5, 1243.3),
  Offset(696.5, 1243.2),
  Offset(695.5, 1243.1),
  Offset(694.5, 1243.0),
  Offset(693.5, 1242.7),
  Offset(692.5, 1242.3),
  Offset(691.5, 1242.1),
  Offset(690.5, 1241.8),
  Offset(689.5, 1241.3),
  Offset(688.5, 1240.8),
  Offset(687.5, 1240.2),
  Offset(686.5, 1239.9),
  Offset(685.5, 1239.3),
  Offset(684.5, 1238.5),
  Offset(683.5, 1237.9),
  Offset(682.5, 1237.0),
  Offset(681.5, 1236.2),
  Offset(680.5, 1235.5),
  Offset(679.5, 1234.2),
  Offset(678.5, 1233.3),
  Offset(677.5, 1232.3),
  Offset(676.5, 1231.1),
  Offset(675.5, 1229.9),
  Offset(674.5, 1228.5),
  Offset(673.5, 1227.0),
  Offset(672.5, 1225.2),
  Offset(671.5, 1222.9),
  Offset(670.5, 1219.7),
];
