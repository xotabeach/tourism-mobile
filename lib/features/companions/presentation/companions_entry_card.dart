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
    // four characters on the right, cut by the card's edge. Laid out at the
    // mockup's width and scaled to the screen as a whole, so the picture is
    // the same on every phone, only its size changes (owner, 2026-10-18:
    // on a wider phone the characters stood differently).
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          child: SizedBox(width: _mockupWidth, child: _card(here)),
        ),
      ),
    );
  }

  Widget _card(CompanionGroup? here) {
    const textWidth = _mockupWidth * 0.63;
    return Container(
      width: _mockupWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
      ),
      // The outline's width, as when it was part of the decoration: the
      // card and its characters stay exactly where they were.
      padding: const EdgeInsets.all(2),
      // Over the characters, so the yellow one standing in the corner
      // does not cover the outline (FRONTEND-98).
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue, width: 2),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: textWidth,
            right: 0,
            top: 6,
            bottom: 0,
            child: ExcludeSemantics(child: CustomPaint(painter: _FourBeans())),
          ),
          // The full card, with both buttons, sets the height in every
          // state: with one button the card stays as tall and the
          // characters keep their size (FRONTEND-100).
          Visibility(
            visible: here == null,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _content(textWidth, null),
          ),
          if (here != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: textWidth,
              child: _content(textWidth, here),
            ),
        ],
      ),
    );
  }

  /// The words and buttons on the left; [here] is the group already
  /// gathering for this route, or null.
  Widget _content(double textWidth, CompanionGroup? here) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 9, 0, 6.5),
    child: SizedBox(
      width: textWidth - 8,
      child: Column(
        mainAxisSize: here == null ? MainAxisSize.min : MainAxisSize.max,
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
                ? '${here.organizerName} зовёт вас на этот маршрут. '
                      'Загляните, кто уже у костра'
                : 'Ваша группа уже собирается. Загляните, кто уже у костра',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 11.5,
              height: 1.25,
              color: AppColors.secondaryInk,
            ),
          ),
          if (here == null) const SizedBox(height: 17) else const Spacer(),
          if (here != null)
            _CardButton(
              label: here.isInvitation ? 'Посмотреть приглашение' : 'К группе',
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
  );
}

/// The card's width on the 375-point mockup.
const _mockupWidth = 343.0;

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
      bool faceless = false,
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
        faceless: faceless,
        face: face,
        stickToRight: stickToRight,
        look: BeanLook(kind: kind, accessory: hat, shape: shape),
      ),
    );

    bean(0.4985, 0.42, 0.365, BeanKind.pin, hat: BeanHat.flatCap, lookX: 0.3);
    bean(0.25, 0.66, 0.49, BeanKind.tall, lookX: 0.4);
    bean(
      0.721,
      0.619,
      0.499,
      BeanKind.round,
      faceless: true,
      stickToRight: false,
    );
    _paintCardRedFace(canvas, size);
    _paintCardYellow(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FourBeans oldDelegate) => false;
}

// The yellow one of the card, laid out by the designer's mockup
// (FRONTEND-87, owner 2026-10-16: «пиксель в пиксель»). Everything is in
// the mockup's pixels, where the card's outer edge runs from (37, 981),
// 826 wide. The outline, the smile, the arms and the light streak were
// traced from the mockup; the eyes, their shine and the hat are its
// measured sizes and places.
/// Moves [canvas] into the mockup's pixels: the painter starts at 63% of
/// the card's outer width, inside its 2-wide border and 6 below it, and is
/// 4 narrower than the rest of the card.
void _toMockup(Canvas canvas, Size size) {
  final outer = (size.width + 4) / 0.37;
  final u = outer / 826;
  canvas.translate(-(37 * u + 2 + outer * 0.63), -(981 * u + 8));
  canvas.scale(u);
}

/// The red one's cross face, traced from the mockup.
void _paintCardRedFace(Canvas canvas, Size size) {
  canvas.save();
  _toMockup(canvas, size);
  final black = Paint()..color = Colors.black;
  final white = Paint()..color = Colors.white;
  canvas.drawPath(Path()..addPolygon(_redEyeLeft, true), black);
  canvas.drawPath(Path()..addPolygon(_redEyeRight, true), black);
  for (final c in const [Offset(762.9, 1087.3), Offset(787.9, 1086.7)]) {
    canvas.drawOval(Rect.fromCenter(center: c, width: 3.2, height: 6.4), white);
  }
  canvas.drawPath(Path()..addPolygon(_redMouth, true), white);
  canvas.restore();
}

void _paintCardYellow(Canvas canvas, Size size) {
  canvas.save();
  _toMockup(canvas, size);

  // Arms: one smooth stroke each, bending up toward the hand.
  final arm = Paint()
    ..color = const Color(0xFFDCBC1A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 13.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(_smooth(_yellowArmLeft), arm);
  canvas.drawPath(_smooth(_yellowArmRight), arm);
  // The legs, just showing at the card's bottom edge.
  final leg = Paint()
    ..color = const Color(0xFFDCBC1A)
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(667, 1300), const Offset(662.5, 1350), leg);
  canvas.drawLine(const Offset(727, 1300), const Offset(731.5, 1350), leg);

  final body = Path()..addPolygon(_yellowBody, true);
  canvas.drawPath(
    body,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDCB2C), Color(0xFFF3C226)],
      ).createShader(const Rect.fromLTRB(600, 1120, 800, 1340)),
  );
  canvas.save();
  canvas.clipPath(body);
  canvas.drawPath(
    Path()..addPolygon(_yellowShine, true),
    Paint()
      ..color = const Color(0xFFF4D94B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
  );
  canvas.restore();

  for (final (eye, shine) in const [
    (Offset(670.5, 1182), Offset(672, 1171.9)),
    (Offset(723.5, 1182), Offset(725, 1171.9)),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 23, height: 44),
      Paint()..color = Colors.black,
    );
    canvas.drawOval(
      Rect.fromCenter(center: shine, width: 7.6, height: 14),
      Paint()..color = Colors.white,
    );
  }
  canvas.drawPath(
    Path()..addPolygon(_yellowMouth, true),
    Paint()..color = Colors.white,
  );

  // Level, centred over the face, set 3 lower than the mockup's 1072 so
  // the brim rests on the head (owner, 2026-10-16).
  paintHatArtIn(
    canvas,
    BeanHat.strawHat,
    const Rect.fromLTWH(620.5, 1075, 162, 67),
  );
  canvas.restore();
}

/// A smooth line through [points] (Catmull-Rom as cubic Béziers).
Path _smooth(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i == 0 ? 0 : i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

// Traced along the middle of the mockup's arms, from the hand into the body.
const _yellowArmLeft = <Offset>[
  Offset(575, 1222.5),
  Offset(581, 1227),
  Offset(589, 1233.5),
  Offset(597, 1239.5),
  Offset(605, 1243.5),
  Offset(613, 1247),
  Offset(621, 1251),
  Offset(636, 1258),
];

const _yellowArmRight = <Offset>[
  Offset(822, 1223.5),
  Offset(816, 1228.5),
  Offset(808, 1234.5),
  Offset(800, 1240),
  Offset(792, 1243.5),
  Offset(784, 1246),
  Offset(776, 1247.5),
  Offset(760, 1252),
];

// The light streak down the top left, traced: its outer edge on the
// body's edge, its inner edge 9–13 in.
const _yellowShine = <Offset>[
  Offset(662, 1124),
  Offset(645, 1127),
  Offset(634, 1132),
  Offset(627, 1137),
  Offset(623, 1142),
  Offset(620, 1148),
  Offset(617, 1154),
  Offset(614, 1160),
  Offset(611, 1168),
  Offset(609, 1178),
  Offset(609, 1186),
  Offset(613, 1190),
  Offset(619, 1186),
  Offset(621, 1176),
  Offset(624, 1164),
  Offset(627, 1156),
  Offset(629, 1150),
  Offset(633, 1144),
  Offset(638, 1139),
  Offset(645, 1134),
  Offset(654, 1131),
  Offset(661, 1129),
];

const _yellowBody = <Offset>[
  Offset(700.0, 1118.8),
  Offset(685.2, 1119.7),
  Offset(672.0, 1121.6),
  Offset(660.6, 1124.3),
  Offset(651.4, 1127.0),
  Offset(645.0, 1129.5),
  Offset(639.2, 1131.5),
  Offset(635.0, 1133.5),
  Offset(631.8, 1135.5),
  Offset(629.4, 1137.5),
  Offset(627.6, 1139.5),
  Offset(626.2, 1141.5),
  Offset(624.8, 1143.5),
  Offset(623.6, 1145.5),
  Offset(622.4, 1147.5),
  Offset(621.2, 1149.5),
  Offset(620.0, 1151.5),
  Offset(619.0, 1153.5),
  Offset(618.0, 1155.5),
  Offset(617.2, 1157.5),
  Offset(616.2, 1159.5),
  Offset(615.4, 1161.5),
  Offset(614.6, 1163.5),
  Offset(613.8, 1165.5),
  Offset(612.8, 1167.5),
  Offset(612.2, 1169.5),
  Offset(611.6, 1171.5),
  Offset(611.2, 1173.5),
  Offset(610.8, 1175.5),
  Offset(610.6, 1177.5),
  Offset(610.2, 1179.5),
  Offset(609.8, 1181.5),
  Offset(609.4, 1183.5),
  Offset(609.2, 1185.5),
  Offset(609.0, 1187.5),
  Offset(609.0, 1189.5),
  Offset(609.0, 1191.5),
  Offset(609.0, 1193.5),
  Offset(609.0, 1195.5),
  Offset(609.2, 1197.5),
  Offset(609.4, 1199.5),
  Offset(609.6, 1201.5),
  Offset(609.8, 1203.5),
  Offset(610.2, 1205.5),
  Offset(610.4, 1207.5),
  Offset(610.8, 1209.5),
  Offset(611.2, 1211.5),
  Offset(611.8, 1213.5),
  Offset(612.2, 1215.5),
  Offset(612.8, 1217.5),
  Offset(613.2, 1219.5),
  Offset(613.6, 1221.5),
  Offset(614.0, 1223.5),
  Offset(614.6, 1225.5),
  Offset(615.0, 1227.5),
  Offset(615.6, 1229.5),
  Offset(616.4, 1231.5),
  Offset(617.0, 1233.5),
  Offset(617.6, 1235.5),
  Offset(618.2, 1237.5),
  Offset(618.8, 1239.5),
  Offset(619.2, 1241.5),
  Offset(619.8, 1243.5),
  Offset(620.4, 1245.5),
  Offset(621.2, 1247.5),
  Offset(622.0, 1249.5),
  Offset(623.0, 1251.5),
  Offset(623.8, 1253.5),
  Offset(624.8, 1255.5),
  Offset(625.6, 1257.5),
  Offset(626.6, 1259.5),
  Offset(627.6, 1261.5),
  Offset(628.8, 1263.5),
  Offset(629.8, 1265.5),
  Offset(631.2, 1267.5),
  Offset(632.2, 1269.5),
  Offset(633.4, 1271.5),
  Offset(634.6, 1273.5),
  Offset(635.6, 1275.5),
  Offset(636.6, 1277.5),
  Offset(637.8, 1279.5),
  Offset(638.8, 1281.5),
  Offset(639.8, 1283.5),
  Offset(641.2, 1285.5),
  Offset(642.4, 1287.5),
  Offset(643.6, 1289.5),
  Offset(644.8, 1291.5),
  Offset(646.0, 1293.5),
  Offset(647.2, 1295.5),
  Offset(648.4, 1297.5),
  Offset(649.6, 1299.5),
  Offset(650.8, 1301.5),
  Offset(652.2, 1303.5),
  Offset(653.4, 1305.5),
  Offset(654.8, 1307.5),
  Offset(656.2, 1309.5),
  Offset(657.6, 1311.5),
  Offset(659.0, 1313.5),
  Offset(660.4, 1315.5),
  Offset(661.4, 1317.5),
  Offset(662.6, 1319.5),
  Offset(663.8, 1321.5),
  Offset(666.6, 1327.3),
  Offset(671.0, 1336.7),
  Offset(677.2, 1349.7),
  Offset(684.4, 1362.3),
  Offset(693.2, 1370.5),
  Offset(701.8, 1370.5),
  Offset(710.6, 1362.3),
  Offset(717.8, 1349.7),
  Offset(724.0, 1336.7),
  Offset(728.6, 1327.3),
  Offset(731.4, 1321.5),
  Offset(732.6, 1319.5),
  Offset(733.8, 1317.5),
  Offset(735.0, 1315.5),
  Offset(736.2, 1313.5),
  Offset(737.6, 1311.5),
  Offset(739.0, 1309.5),
  Offset(740.4, 1307.5),
  Offset(741.6, 1305.5),
  Offset(743.0, 1303.5),
  Offset(744.4, 1301.5),
  Offset(745.6, 1299.5),
  Offset(746.8, 1297.5),
  Offset(748.2, 1295.5),
  Offset(749.4, 1293.5),
  Offset(750.6, 1291.5),
  Offset(751.8, 1289.5),
  Offset(753.0, 1287.5),
  Offset(754.0, 1285.5),
  Offset(755.2, 1283.5),
  Offset(756.4, 1281.5),
  Offset(757.6, 1279.5),
  Offset(758.8, 1277.5),
  Offset(760.0, 1275.5),
  Offset(761.0, 1273.5),
  Offset(762.0, 1271.5),
  Offset(763.0, 1269.5),
  Offset(764.0, 1267.5),
  Offset(765.0, 1265.5),
  Offset(766.0, 1263.5),
  Offset(767.0, 1261.5),
  Offset(768.2, 1259.5),
  Offset(769.4, 1257.5),
  Offset(770.6, 1255.5),
  Offset(771.8, 1253.5),
  Offset(772.8, 1251.5),
  Offset(773.6, 1249.5),
  Offset(774.4, 1247.5),
  Offset(775.2, 1245.5),
  Offset(776.0, 1243.5),
  Offset(776.6, 1241.5),
  Offset(777.2, 1239.5),
  Offset(777.8, 1237.5),
  Offset(778.2, 1235.5),
  Offset(778.6, 1233.5),
  Offset(779.4, 1231.5),
  Offset(780.0, 1229.5),
  Offset(780.6, 1227.5),
  Offset(781.2, 1225.5),
  Offset(781.8, 1223.5),
  Offset(782.2, 1221.5),
  Offset(782.8, 1219.5),
  Offset(783.2, 1217.5),
  Offset(783.8, 1215.5),
  Offset(784.4, 1213.5),
  Offset(785.0, 1211.5),
  Offset(785.4, 1209.5),
  Offset(786.0, 1207.5),
  Offset(786.4, 1205.5),
  Offset(786.6, 1203.5),
  Offset(786.8, 1201.5),
  Offset(786.8, 1199.5),
  Offset(786.6, 1197.5),
  Offset(786.6, 1195.5),
  Offset(786.6, 1193.5),
  Offset(786.6, 1191.5),
  Offset(786.8, 1189.5),
  Offset(787.0, 1187.5),
  Offset(786.8, 1185.5),
  Offset(786.6, 1183.5),
  Offset(786.4, 1181.5),
  Offset(786.2, 1179.5),
  Offset(785.8, 1177.5),
  Offset(785.6, 1175.5),
  Offset(785.4, 1173.5),
  Offset(785.0, 1171.5),
  Offset(784.4, 1169.5),
  Offset(784.0, 1167.5),
  Offset(783.4, 1165.5),
  Offset(782.6, 1163.5),
  Offset(782.0, 1161.5),
  Offset(781.4, 1159.5),
  Offset(780.6, 1157.5),
  Offset(779.8, 1155.5),
  Offset(779.0, 1153.5),
  Offset(778.0, 1151.5),
  Offset(777.0, 1149.5),
  Offset(776.0, 1147.5),
  Offset(775.0, 1145.5),
  Offset(774.0, 1143.5),
  Offset(772.8, 1141.5),
  Offset(771.2, 1139.5),
  Offset(769.2, 1137.5),
  Offset(766.6, 1135.5),
  Offset(763.2, 1133.5),
  Offset(759.0, 1131.5),
  Offset(753.8, 1129.5),
  Offset(747.8, 1127.0),
  Offset(739.0, 1124.3),
  Offset(728.0, 1121.6),
  Offset(715.0, 1119.7),
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

const _redEyeLeft = <Offset>[
  Offset(762.3, 1081.5),
  Offset(761.6, 1082.5),
  Offset(761.0, 1083.5),
  Offset(760.7, 1084.5),
  Offset(760.3, 1085.5),
  Offset(760.1, 1086.5),
  Offset(760.0, 1087.5),
  Offset(759.8, 1088.5),
  Offset(759.7, 1089.5),
  Offset(759.5, 1090.5),
  Offset(759.4, 1091.5),
  Offset(759.4, 1092.5),
  Offset(759.5, 1093.5),
  Offset(759.7, 1094.5),
  Offset(759.9, 1095.5),
  Offset(760.1, 1096.5),
  Offset(760.7, 1097.5),
  Offset(761.7, 1098.5),
  Offset(764.1, 1099.5),
  Offset(766.5, 1099.5),
  Offset(768.4, 1098.5),
  Offset(769.2, 1097.5),
  Offset(769.7, 1096.5),
  Offset(769.9, 1095.5),
  Offset(770.1, 1094.5),
  Offset(770.1, 1093.5),
  Offset(770.1, 1092.5),
  Offset(770.1, 1091.5),
  Offset(770.1, 1090.5),
  Offset(770.1, 1089.5),
  Offset(770.1, 1088.5),
  Offset(769.9, 1087.5),
  Offset(769.6, 1086.5),
  Offset(769.0, 1085.5),
  Offset(768.1, 1084.5),
  Offset(767.2, 1083.5),
  Offset(766.2, 1082.5),
  Offset(765.1, 1081.5),
];

const _redEyeRight = <Offset>[
  Offset(789.1, 1081.5),
  Offset(788.0, 1082.5),
  Offset(786.9, 1083.5),
  Offset(786.1, 1084.5),
  Offset(785.0, 1085.5),
  Offset(784.4, 1086.5),
  Offset(784.0, 1087.5),
  Offset(783.8, 1088.5),
  Offset(783.6, 1089.5),
  Offset(783.5, 1090.5),
  Offset(783.5, 1091.5),
  Offset(783.5, 1092.5),
  Offset(783.6, 1093.5),
  Offset(783.8, 1094.5),
  Offset(784.0, 1095.5),
  Offset(784.3, 1096.5),
  Offset(784.9, 1097.5),
  Offset(785.9, 1098.5),
  Offset(788.2, 1099.5),
  Offset(790.6, 1099.5),
  Offset(792.6, 1098.5),
  Offset(793.3, 1097.5),
  Offset(793.9, 1096.5),
  Offset(794.1, 1095.5),
  Offset(794.2, 1094.5),
  Offset(794.3, 1093.5),
  Offset(794.3, 1092.5),
  Offset(794.3, 1091.5),
  Offset(794.3, 1090.5),
  Offset(794.3, 1089.5),
  Offset(794.1, 1088.5),
  Offset(794.0, 1087.5),
  Offset(793.9, 1086.5),
  Offset(793.6, 1085.5),
  Offset(793.3, 1084.5),
  Offset(793.0, 1083.5),
  Offset(792.5, 1082.5),
  Offset(791.8, 1081.5),
];

const _redMouth = <Offset>[
  Offset(777.1, 1106.6),
  Offset(773.9, 1107.5),
  Offset(771.9, 1108.5),
  Offset(770.3, 1109.5),
  Offset(769.1, 1110.5),
  Offset(768.0, 1111.5),
  Offset(767.2, 1112.5),
  Offset(766.4, 1113.5),
  Offset(765.9, 1114.5),
  Offset(765.4, 1115.5),
  Offset(765.2, 1116.5),
  Offset(765.0, 1117.5),
  Offset(764.9, 1118.5),
  Offset(765.0, 1119.5),
  Offset(765.3, 1120.8),
  Offset(789.0, 1120.8),
  Offset(789.3, 1119.5),
  Offset(789.3, 1118.5),
  Offset(789.2, 1117.5),
  Offset(789.0, 1116.5),
  Offset(788.8, 1115.5),
  Offset(788.3, 1114.5),
  Offset(787.7, 1113.5),
  Offset(787.0, 1112.5),
  Offset(786.1, 1111.5),
  Offset(785.1, 1110.5),
  Offset(784.0, 1109.5),
  Offset(782.5, 1108.5),
  Offset(780.3, 1107.5),
];
