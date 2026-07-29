import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

/// Colors from Figma settings pixel spec.
abstract final class SettingsColors {
  static const Color accent = AppColors.accentBlue;
  static const Color accentIcon = AppColors.accentBlueIcon;
  static const Color link = AppColors.accentBlueIcon;
  static const Color supportSubtitle = Color(0xFFB8CBE6);
  static const Color circleButton = Color(0xFF1C1C1E);
  static const Color toggleOff = Color(0xFFE5E5E5);
  static const Color checkboxBorder = Color(0xFFB9B9B9);
  static const Color fieldFill = Color(0xFFE7E7E7);
  static const Color hairline = Color(0xFFE3E3E3);

  /// Banner fill axis ≈31° — §3.3: `#A5D4EA` → `#6580F5`.
  static const Color bannerGradientStart = Color(0xFFA5D4EA);
  static const Color bannerGradientEnd = Color(0xFF6580F5);
  static const Alignment bannerGradientEndAlign = Alignment(1.0, 0.18);

  /// Title + plus shared ramp — §3.8.
  static const Color titleGradientStart = Color(0xFF3D89C3);
  static const Color titleGradientEnd = Color(0xFF183DE5);

  /// Arc / cursor — solid `#1537E7`, no alpha (§3.6 / §3.7).
  static const Color arcStroke = Color(0xFF1537E7);
  static const Color cursorFill = Color(0xFF1537E7);

  static const Color bannerBorderTop = Color(0xFF67A7F8);
  static const Color bannerBorderBottom = Color(0xFF3357F6);

  static const Color yearGradientStart = Color(0xFF72B2D2);
  static const Color yearGradientEnd = Color(0xFF5C7AF4);
  static const Alignment yearGradientEndAlign = Alignment(1.0, 0.40);
  static const Color monthFlat = Color(0xFF97B7E0);
  static const Color monthBorder = Color(0xFF7FA5D8);
}

/// Shared concentric geometry for banner decor (§3.1).
abstract final class TravelBannerGeometry {
  /// ≈ 7.3 pt left of right edge, 1.0 pt above bottom.
  static Offset centerFor(Size size) =>
      Offset(size.width - 7.3, size.height - 1.0);

  static const double diskRadius = 101.5;
  static const double arcRadius = 110.4;
  static const double arcDash = 9;
  static const double arcGap = 2.6;
  static const double arcStrokeWidth = 2;
  static const double markerPolarDegrees = -166;
}

abstract final class SettingsMetrics {
  static const double rowHeight = 64;
  static const double rowHeightDense = 52;
  static const double rowGap = 14;
  static const double iconBox = 32;
  static const double headerButton = 46;
  static const double contentInset = 16;
  static const double bannerHeight = 132;
}

/// Shared chrome: brand + dark circular back (+ optional check).
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.showSave = false,
    this.onSave,
    this.headerOverlay,
    this.padding,
    this.spaceChildren = true,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool showSave;
  final VoidCallback? onSave;

  /// Optional content above the title (e.g. Travel+ banner).
  final Widget? headerOverlay;
  final EdgeInsetsGeometry? padding;
  final bool spaceChildren;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.pageSurface,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  padding ??
                  EdgeInsets.fromLTRB(
                    SettingsMetrics.contentInset,
                    top + 8,
                    SettingsMetrics.contentInset,
                    0,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsTopBar(
                    showSave: showSave,
                    onSave: onSave ?? () => context.pop(),
                  ),
                  if (headerOverlay != null) ...[
                    const SizedBox(height: 12),
                    headerOverlay!,
                  ],
                  if (title != null) ...[
                    SizedBox(height: headerOverlay == null ? 12 : 14),
                    Text(
                      title!,
                      style: AppTypography.settingsSectionTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: AppTypography.settingsRowSubtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ] else if (headerOverlay == null)
                    const SizedBox(height: 12)
                  else
                    const SizedBox(height: SettingsMetrics.rowGap),
                  if (spaceChildren) ..._spaced(children) else ...children,
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(const SizedBox(height: SettingsMetrics.rowGap));
      out.add(children[i]);
    }
    return out;
  }
}

class SettingsTopBar extends StatelessWidget {
  const SettingsTopBar({
    super.key,
    this.showSave = false,
    this.onSave,
    this.brandColor,
    this.buttonColor,
    this.iconColor,
    this.glassButtons = false,
  });

  final bool showSave;
  final VoidCallback? onSave;
  final Color? brandColor;
  final Color? buttonColor;
  final Color? iconColor;
  final bool glassButtons;

  @override
  Widget build(BuildContext context) {
    final brand = brandColor ?? AppColors.settingsBrand;
    return SizedBox(
      height: SettingsMetrics.headerButton,
      child: Row(
        children: [
          SettingsCircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
            background: buttonColor ?? SettingsColors.circleButton,
            iconColor: iconColor ?? Colors.white,
            iconSize: 18,
            size: SettingsMetrics.headerButton,
            glass: glassButtons,
          ),
          Expanded(
            child: Text(
              'КРЫМТРИП',
              textAlign: TextAlign.center,
              style: AppTypography.settingsBrand.copyWith(color: brand),
            ),
          ),
          if (showSave)
            SettingsCircleIconButton(
              icon: Icons.check_rounded,
              onTap: onSave ?? () => context.pop(),
              background: buttonColor ?? SettingsColors.circleButton,
              iconColor: iconColor ?? Colors.white,
              iconSize: 22,
              size: SettingsMetrics.headerButton,
              glass: glassButtons,
            )
          else
            const SizedBox(width: SettingsMetrics.headerButton),
        ],
      ),
    );
  }
}

class SettingsCircleIconButton extends StatelessWidget {
  const SettingsCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = SettingsColors.circleButton,
    this.iconColor = Colors.white,
    this.iconSize = 18,
    this.size = SettingsMetrics.headerButton,
    this.glass = false,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;
  final double iconSize;
  final double size;
  final bool glass;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: iconSize, color: iconColor);
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: glass || borderColor != null
                  ? Border.all(
                      color:
                          borderColor ??
                          Colors.white.withValues(alpha: 0.75),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Settings row — 64 pt with subtitle / 52 pt without (Figma §2.3).
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
    this.emphasized = false,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool emphasized;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final height = dense || !hasSubtitle
        ? SettingsMetrics.rowHeightDense
        : SettingsMetrics.rowHeight;
    final bg = emphasized ? SettingsColors.accent : AppColors.elevatedSurface;
    final titleColor = emphasized ? Colors.white : AppColors.settingsInk;
    final subColor = emphasized
        ? SettingsColors.supportSubtitle
        : AppColors.settingsSecondaryInk;
    final iconColor = emphasized ? Colors.white : SettingsColors.accentIcon;
    final chevronColor = emphasized ? Colors.white : const Color(0xFF000000);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                unawaited(HapticFeedback.selectionClick());
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: emphasized
                ? AppShadows.settingsElevated
                : AppShadows.settingsTile,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  SizedBox.square(
                    dimension: SettingsMetrics.iconBox,
                    child: Icon(icon, size: 28, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.settingsRowTitle.copyWith(
                          color: titleColor,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            color: subColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: chevronColor,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 56,
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? SettingsColors.accent : SettingsColors.toggleOff,
          borderRadius: BorderRadius.circular(AppRadii.capsule),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SettingsNavTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: () => onChanged(!value),
      trailing: SettingsToggle(value: value, onChanged: onChanged),
    );
  }
}

class SettingsChatCta extends StatelessWidget {
  const SettingsChatCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsNavTile(
      title: 'Чат с поддержкой',
      subtitle: 'Напишите нам если не нашли ответ',
      icon: Icons.chat_bubble_outline_rounded,
      emphasized: true,
      onTap: onTap,
    );
  }
}

class SettingsHairline extends StatelessWidget {
  const SettingsHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Divider(height: 1, thickness: 1, color: SettingsColors.hairline),
    );
  }
}

class SettingsPrimaryButton extends StatelessWidget {
  const SettingsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: onPressed == null
            ? AppColors.settingsInk.withValues(alpha: 0.45)
            : AppColors.settingsInk,
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  onPressed!();
                },
          borderRadius: BorderRadius.circular(AppRadii.capsule),
          child: Center(
            child: Text(label, style: AppTypography.settingsCta),
          ),
        ),
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: AppTypography.settingsRowSubtitle.copyWith(
        color: AppColors.settingsInk,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.settingsRowSubtitle,
        filled: true,
        fillColor: SettingsColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.capsule),
          borderSide: BorderSide.none,
        ),
        counterText: '',
      ),
    );
  }
}

/// Travel+ banner — Figma §3 (2nd edition, concentric geometry).
///
/// Decor paints on the **outer** 361×132 frame so §3.1 center
/// `(353.7, 131.0)` stays correct. The 2 pt gradient border is an overlay,
/// not an inset that shrinks the paint area.
class TravelPlusBanner extends StatelessWidget {
  const TravelPlusBanner({
    super.key,
    required this.active,
    required this.subtitle,
    required this.onTap,
  });

  final bool active;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: AppShadows.settingsElevated,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            child: SizedBox(
              height: SettingsMetrics.bannerHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: SettingsColors.bannerGradientEndAlign,
                          colors: [
                            SettingsColors.bannerGradientStart,
                            SettingsColors.bannerGradientEnd,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: CustomPaint(painter: _TravelBannerDecorPainter()),
                  ),
                  const Positioned(
                    left: 16,
                    top: 12,
                    right: 72,
                    child: _TravelPlusTitle(),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _StatusChip(label: subtitle),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SettingsCircleIconButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: onTap,
                      background: Colors.white.withValues(alpha: 0.20),
                      iconColor: Colors.white,
                      iconSize: 20,
                      size: 47,
                      glass: true,
                      borderColor: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  // §3.12 — 2 pt gradient border over the outer frame.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _TravelBannerBorderPainter()),
                    ),
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

/// One ShaderMask over «ТРЕВЕЛ» + geometric «+» (§3.8–3.9).
class _TravelPlusTitle extends StatelessWidget {
  const _TravelPlusTitle();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            SettingsColors.titleGradientStart,
            SettingsColors.titleGradientEnd,
          ],
        ).createShader(bounds),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ТРЕВЕЛ',
              style: TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 50,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: 0,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 18),
            // Optical center of plus sits ~2.3 pt below letter optical center.
            Padding(
              padding: EdgeInsets.only(top: 2.3),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(painter: _TravelPlusMarkPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelPlusMarkPainter extends CustomPainter {
  const _TravelPlusMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const stroke = 6.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width,
          height: stroke,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: stroke,
          height: size.height,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Status chip: no fill, backdrop blur + bottom shadow (§3.10).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 33,
            constraints: const BoxConstraints(minWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            color: Colors.white.withValues(alpha: 0.02),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2 pt vertical gradient stroke matching outer radius (§3.12).
class _TravelBannerBorderPainter extends CustomPainter {
  const _TravelBannerBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.settingsTile),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SettingsColors.bannerBorderTop,
          SettingsColors.bannerBorderBottom,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect.deflate(1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glow + disk + dashed arc + cursor — shared center (§3.4–3.7 / §3.15).
class _TravelBannerDecorPainter extends CustomPainter {
  const _TravelBannerDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = TravelBannerGeometry.centerFor(size);

    // §3.4 soft corner glow (slightly stronger so the top-left disk reads).
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: const Offset(45, 25), radius: 120),
      );
    canvas.drawCircle(const Offset(45, 25), 120, glowPaint);

    // §3.5 light disk (bottom-right concentric lens).
    canvas.drawCircle(
      c,
      TravelBannerGeometry.diskRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // §3.6 arc: exact 90° from 9 o'clock → 12 o'clock (counter-clockwise).
    final arcPaint = Paint()
      ..color = SettingsColors.arcStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = TravelBannerGeometry.arcStrokeWidth
      ..strokeCap = StrokeCap.butt;
    final arcPath = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: TravelBannerGeometry.arcRadius),
        math.pi, // 9 o'clock
        -math.pi / 2, // to 12 o'clock
      );
    _drawDashedPath(
      canvas,
      arcPath,
      arcPaint,
      dash: TravelBannerGeometry.arcDash,
      gap: TravelBannerGeometry.arcGap,
    );

    // §3.7 marker on arc at −166°
    const polar = TravelBannerGeometry.markerPolarDegrees * math.pi / 180;
    final markerPos = Offset(
      c.dx + TravelBannerGeometry.arcRadius * math.cos(polar),
      c.dy + TravelBannerGeometry.arcRadius * math.sin(polar),
    );
    // Tangent toward 12 o'clock (increasing angle from −166° toward −90°).
    final tangent = Offset(-math.sin(polar), math.cos(polar));
    final rotation = math.atan2(tangent.dx, -tangent.dy);
    _drawNavCursor(canvas, markerPos, rotation);
  }

  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  static void _drawNavCursor(Canvas canvas, Offset center, double angle) {
    final paint = Paint()
      ..color = SettingsColors.cursorFill
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // 10 × 19 navigation cursor, nose up, V-notch at base.
    final path = Path()
      ..moveTo(0, -9.5)
      ..lineTo(5, 9.5)
      ..lineTo(0, 5.5)
      ..lineTo(-5, 9.5)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-bleed Travel+ hero used on the paywall (§4.19).
class TravelPlusHeroBackground extends StatelessWidget {
  const TravelPlusHeroBackground({
    super.key,
    required this.topInset,
    required this.subtitle,
    this.child,
  });

  final double topInset;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: SettingsColors.bannerGradientEndAlign,
          colors: [
            SettingsColors.bannerGradientStart,
            SettingsColors.bannerGradientEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _TravelBannerDecorPainter()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  SettingsMetrics.contentInset,
                  topInset + 8,
                  SettingsMetrics.contentInset,
                  0,
                ),
                child: SettingsTopBar(
                  brandColor: Colors.white.withValues(alpha: 0.55),
                  buttonColor: Colors.white.withValues(alpha: 0.20),
                  iconColor: Colors.white,
                  glassButtons: true,
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SettingsMetrics.contentInset,
                ),
                child: _TravelPlusTitle(),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SettingsMetrics.contentInset,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusChip(label: subtitle),
                ),
              ),
              ?child,
            ],
          ),
        ],
      ),
    );
  }
}

/// Kept for screens that still group fields in one card (forms).
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        boxShadow: AppShadows.settingsTile,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: SettingsColors.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsFormCard extends StatelessWidget {
  const SettingsFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.settingsTile),
        boxShadow: AppShadows.settingsTile,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SettingsDashedUpload extends StatelessWidget {
  const SettingsDashedUpload({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xFFC9C9C9),
            radius: 10,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFB0B0B0),
                        width: 1.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Color(0xFFB0B0B0),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Добавить скриншот',
                          style: AppTypography.settingsRowTitle,
                        ),
                        Text(
                          'Это поможет лучше понять проблему',
                          style: AppTypography.settingsRowSubtitle.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
