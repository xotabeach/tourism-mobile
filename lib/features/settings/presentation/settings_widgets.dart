import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_iconography.dart';
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

  /// Switch track off — from Figma export `switch-false.png`.
  static const Color toggleOff = Color(0xFFBCBCBF);

  /// Switch track on — from Figma export `switch-true.png` (`#1267BF`).
  static const Color toggleOn = Color(0xFF1267BF);
  static const Color checkboxBorder = Color(0xFFB9B9B9);
  static const Color fieldFill = Color(0xFFE7E7E7);
  static const Color hairline = Color(0xFFE3E3E3);

  /// Banner fill — Figma property panel: `#90D3EB` → `#547BFC` @ 68%.
  /// Axis ≈31° (§3.3): `begin: topLeft, end: Alignment(1.0, 0.18)`.
  static const Color bannerGradientStart = Color(0xFF90D3EB);
  static const Color bannerGradientEnd = Color(0xFF547BFC);
  static const Alignment bannerGradientEndAlign = Alignment(1.0, 0.18);
  static const List<double> bannerGradientStops = [0.0, 0.68];

  /// Title ramp — Rubik SemiBold ~36: `#0090C6` → `#0038F0`.
  static const Color titleGradientStart = Color(0xFF0090C6);
  static const Color titleGradientEnd = Color(0xFF0038F0);

  /// Title drop shadow — `#000681` @ 25%, blur 3.
  static const Color titleShadow = Color(0x40000681);

  /// Arc / cursor — solid `#1537E7`, no alpha (§3.6 / §3.7).
  static const Color arcStroke = Color(0xFF1537E7);
  static const Color cursorFill = Color(0xFF1537E7);

  /// Inside stroke 3 pt — `#67D6FF` → `#2558FF` @ 66%.
  static const Color bannerBorderTop = Color(0xFF67D6FF);
  static const Color bannerBorderBottom = Color(0xFF2558FF);
  static const List<double> bannerBorderStops = [0.0, 0.66];
  static const double bannerBorderWidth = 3;

  static const Color yearGradientStart = Color(0xFF72B2D2);
  static const Color yearGradientEnd = Color(0xFF5C7AF4);
  static const Alignment yearGradientEndAlign = Alignment(1.0, 0.40);
  static const Color monthFlat = Color(0xFF97B7E0);
  static const Color monthBorder = Color(0xFF7FA5D8);
}

/// Compact settings banner vs full-bleed paywall hero.
enum TravelBannerLayout { compact, hero }

/// Settings Travel+ banner — Figma export `1258 × 480`.
///
/// The blue card fills [designAspectRatio]. Compact numbers are in that
/// design space and scale with `width / designSize.width`.
abstract final class TravelBannerGeometry {
  /// Etalon composition size (visible card ≈ artboard).
  static const Size designSize = Size(1258, 480);
  static const double designAspectRatio = 1258 / 480;

  /// Alias used by painters (card == design frame in the app).
  static Size get cardSize => designSize;

  /// Soft corner radius (Figma card ≈54–62 on the 1258 frame).
  static const double designCornerRadius = 58;

  // —— Title «ТРЕВЕЛ +» ——
  static const double titleLeft = 88;
  static const double titleTop = 76;
  static const double titleFontSize = 118;
  static const double titlePlusSize = 96;
  static const double titlePlusGap = 26;

  // —— CTA pill ——
  static const double ctaLeft = 84;
  static const double ctaWidth = 669;
  static const double ctaHeight = 109;
  static const double ctaFontSize = 48;

  /// From card bottom (Figma y≈303 → bottom ≈480−303−109).
  static const double ctaBottom = 68;

  // —— Chevron circle Ø160 ——
  static const double circleSize = 160;
  static const double circleRight = 74;
  static const double circleBottom = 68;

  // —— Route arc: large radius, top-right → bottom-left, marker low ——
  static const Offset compactArcCenter = Offset(1180, 455);
  static const double compactArcRadius = 420;
  static const double compactSoftArcWidth = 72;

  /// Start near top; negative sweep = CCW toward lower-left.
  static const double compactArcStartDeg = -92;
  static const double compactArcSweepDeg = -100;
  static const double compactMarkerPolarDeg = -170;
  static const double compactArcStroke = 3.2;
  static const double compactArcDash = 16;
  static const double compactArcGap = 9;

  // —— Ambient lights ——
  static const Offset compactTopLeftGlow = Offset(210, 30);
  static const double compactTopLeftGlowRadius = 320;
  static const Offset compactMidGlow = Offset(540, 220);
  static const double compactMidGlowRadius = 230;
  static const Offset compactDiskCenter = Offset(1180, 455);
  static const double compactDiskRadius = 350;

  /// Paywall hero design frame (separate composition).
  static const Size heroDesignSize = Size(393, 275);

  static Offset centerFor(Size size, TravelBannerLayout layout) {
    switch (layout) {
      case TravelBannerLayout.compact:
        final s = size.width / designSize.width;
        return Offset(compactArcCenter.dx * s, compactArcCenter.dy * s);
      case TravelBannerLayout.hero:
        final sx = size.width / heroDesignSize.width;
        return Offset(329.0 * sx, 285.0 * sx);
    }
  }

  static const double diskRadius = 101;
  static const double trackMidRadius = 106;
  static const double arcStrokeWidth = 2.8;
  static const double arcDash = 7.5;
  static const double arcGap = 3.2;
  static const double markerRadius = 101.3;
  static const double markerPolarDegrees = -138.9;
  static const Offset glowOffsetFromCenter = Offset(10.5, -259.5);
  static const double glowRadius = 75.5;
}

abstract final class SettingsMetrics {
  static const double rowHeight = 64;
  static const double rowHeightDense = 52;
  static const double rowGap = 14;
  static const double iconBox = 32;
  static const double headerButton = 46;
  static const double contentInset = 16;
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
    this.borderWidth = 1.5,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;
  final double iconSize;
  final double size;
  final bool glass;
  final Color? borderColor;
  final double borderWidth;

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
                          borderColor ?? Colors.white.withValues(alpha: 0.75),
                      width: borderWidth,
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
    this.iconAsset,
    this.onTap,
    this.trailing,
    this.emphasized = false,
    this.dense = false,
  }) : assert(icon == null || iconAsset == null);

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? iconAsset;
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
                if (iconAsset != null || icon != null) ...[
                  SizedBox.square(
                    dimension: SettingsMetrics.iconBox,
                    child: iconAsset != null
                        ? AppAssetIcon(
                            iconAsset!,
                            size: AppIconography.settings,
                            color: iconColor,
                          )
                        : Icon(icon, size: 28, color: iconColor),
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

/// Figma switch: off = round white thumb on grey; on = elongated white capsule
/// on blue (`switch-true.png` / `switch-false.png`). Flat, no thumb shadow.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _width = 51;
  static const double _height = 28;
  static const double _pad = 3;
  static const double _thumbH = _height - _pad * 2;
  static const double _thumbOnW = 30;

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
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: value ? SettingsColors.toggleOn : SettingsColors.toggleOff,
          borderRadius: BorderRadius.circular(AppRadii.capsule),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: value ? _thumbOnW : _thumbH,
            height: _thumbH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.capsule),
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
    this.iconAsset,
  }) : assert(icon == null || iconAsset == null);

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return SettingsNavTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconAsset: iconAsset,
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
      iconAsset: AppIconography.settingsChat,
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
          child: Center(child: Text(label, style: AppTypography.settingsCta)),
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

/// Travel+ banner — Figma export `1258×480` (aspect locked, proportional scale).
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
    return AspectRatio(
      aspectRatio: TravelBannerGeometry.designAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s =
              constraints.maxWidth / TravelBannerGeometry.designSize.width;
          final radius = TravelBannerGeometry.designCornerRadius * s;
          final circle = TravelBannerGeometry.circleSize * s;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                onTap();
              },
              borderRadius: BorderRadius.circular(radius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x40001580),
                      blurRadius: 32 * s,
                      offset: Offset(0, 14 * s),
                    ),
                    BoxShadow(
                      color: const Color(0x24000000),
                      blurRadius: 18 * s,
                      offset: Offset(0, 8 * s),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
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
                              stops: SettingsColors.bannerGradientStops,
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: _TravelBannerDecorPainter(
                            layout: TravelBannerLayout.compact,
                          ),
                        ),
                      ),
                      Positioned(
                        left: TravelBannerGeometry.titleLeft * s,
                        top: TravelBannerGeometry.titleTop * s,
                        child: _TravelPlusTitle(designScale: s),
                      ),
                      Positioned(
                        left: TravelBannerGeometry.ctaLeft * s,
                        bottom: TravelBannerGeometry.ctaBottom * s,
                        child: _StatusChip(
                          label: subtitle,
                          designScale: s,
                        ),
                      ),
                      Positioned(
                        right: TravelBannerGeometry.circleRight * s,
                        bottom: TravelBannerGeometry.circleBottom * s,
                        child: SettingsCircleIconButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: onTap,
                          background: Colors.white.withValues(alpha: 0.24),
                          iconColor: Colors.white,
                          iconSize: circle * 0.52,
                          size: circle,
                          glass: false,
                          borderColor: Colors.white.withValues(alpha: 0.75),
                          borderWidth: math.max(1.5, 2.2 * s),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _TravelBannerBorderPainter(
                              radius: radius,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One ShaderMask over «ТРЕВЕЛ» + geometric «+», scaled from the card design.
class _TravelPlusTitle extends StatelessWidget {
  const _TravelPlusTitle({this.designScale});

  /// Card scale `cardWidth / cardSize.width`. Null = paywall hero defaults.
  final double? designScale;

  @override
  Widget build(BuildContext context) {
    final s = designScale;
    final fontSize = s != null
        ? TravelBannerGeometry.titleFontSize * s
        : 40.0;
    final plus = s != null ? TravelBannerGeometry.titlePlusSize * s : 20.0;
    final gap = s != null ? TravelBannerGeometry.titlePlusGap * s : 8.0;
    final shadowBlur = s != null ? 12 * s : 3.0;
    final shadowOffset = s != null ? Offset(0, 3 * s) : const Offset(0, 1);

    final titleStyle = TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: s != null ? 1.0 * s : 0.2,
      color: Colors.white,
    );
    final shadowStyle = titleStyle.copyWith(
      color: const Color(0x99000681),
      shadows: [
        Shadow(
          color: const Color(0x99000681),
          blurRadius: shadowBlur,
          offset: shadowOffset,
        ),
        if (s != null)
          Shadow(
            color: const Color(0x40000681),
            blurRadius: 22 * s,
            offset: Offset(0, 6 * s),
          ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ТРЕВЕЛ', style: shadowStyle),
              SizedBox(width: gap),
              SizedBox(
                width: plus,
                height: plus,
                child: const CustomPaint(
                  painter: _TravelPlusMarkPainter(
                    color: Color(0x73000681),
                  ),
                ),
              ),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              SettingsColors.titleGradientStart,
              SettingsColors.titleGradientEnd,
            ],
          ).createShader(bounds),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('ТРЕВЕЛ', style: titleStyle),
              SizedBox(width: gap),
              SizedBox(
                width: plus,
                height: plus,
                child: const CustomPaint(painter: _TravelPlusMarkPainter()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TravelPlusMarkPainter extends CustomPainter {
  const _TravelPlusMarkPainter({this.color = Colors.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = size.shortestSide * 0.23;
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
  bool shouldRepaint(covariant _TravelPlusMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Status chip / CTA pill — glass capsule scaled from the card design.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.designScale});

  final String label;
  final double? designScale;

  @override
  Widget build(BuildContext context) {
    final s = designScale;
    final height = s != null ? TravelBannerGeometry.ctaHeight * s : 33.0;
    final width = s != null ? TravelBannerGeometry.ctaWidth * s : 200.0;
    final fontSize = s != null ? TravelBannerGeometry.ctaFontSize * s : 12.0;
    final hPad = s != null ? 36 * s : 16.0;
    final blur = s != null ? 16 * s : 8.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        boxShadow: [
          BoxShadow(
            color: const Color(0x59000A4A),
            blurRadius: s != null ? 28 * s : 6,
            offset: Offset(0, s != null ? 12 * s : 2),
          ),
          BoxShadow(
            color: const Color(0x33000000),
            blurRadius: s != null ? 14 * s : 4,
            offset: Offset(0, s != null ? 5 * s : 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.capsule),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            height: height,
            width: width,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            alignment: Alignment.center,
            color: Colors.white.withValues(alpha: 0.22),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: const Color(0x66000000),
                    blurRadius: s != null ? 6 * s : 2,
                    offset: Offset(0, s != null ? 1.5 * s : 0.5),
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

/// Inside gradient stroke matching the scaled outer radius.
class _TravelBannerBorderPainter extends CustomPainter {
  const _TravelBannerBorderPainter({this.radius = AppRadii.settingsTile});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.max(
      SettingsColors.bannerBorderWidth,
      size.width * (3.2 / TravelBannerGeometry.cardSize.width),
    );
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SettingsColors.bannerBorderTop,
          SettingsColors.bannerBorderBottom,
        ],
        stops: SettingsColors.bannerBorderStops,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect.deflate(width / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _TravelBannerBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Multilayer decor: top-left light, soft route band, dashed arc, nav cursor.
class _TravelBannerDecorPainter extends CustomPainter {
  const _TravelBannerDecorPainter({this.layout = TravelBannerLayout.compact});

  final TravelBannerLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout == TravelBannerLayout.compact) {
      _paintCompact(canvas, size);
      return;
    }
    _paintHero(canvas, size);
  }

  void _paintCompact(Canvas canvas, Size size) {
    final s = size.width / TravelBannerGeometry.cardSize.width;
    final c = Offset(
      TravelBannerGeometry.compactArcCenter.dx * s,
      TravelBannerGeometry.compactArcCenter.dy * s,
    );
    final arcR = TravelBannerGeometry.compactArcRadius * s;
    const start = TravelBannerGeometry.compactArcStartDeg * math.pi / 180;
    const sweep = TravelBannerGeometry.compactArcSweepDeg * math.pi / 180;

    // Soft pale mass — top-left (Figma depth layer).
    final tl = Offset(
      TravelBannerGeometry.compactTopLeftGlow.dx * s,
      TravelBannerGeometry.compactTopLeftGlow.dy * s,
    );
    final tlR = TravelBannerGeometry.compactTopLeftGlowRadius * s;
    canvas.drawCircle(
      tl,
      tlR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.50),
            const Color(0xFFC5EAF8).withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: tl, radius: tlR)),
    );

    // Soft mid-field brightness (keeps the fill from reading as one gradient).
    final mid = Offset(
      TravelBannerGeometry.compactMidGlow.dx * s,
      TravelBannerGeometry.compactMidGlow.dy * s,
    );
    final midR = TravelBannerGeometry.compactMidGlowRadius * s;
    canvas.drawCircle(
      mid,
      midR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: mid, radius: midR)),
    );

    // Pale disk behind the right-side composition.
    final diskR = TravelBannerGeometry.compactDiskRadius * s;
    final diskC = Offset(
      TravelBannerGeometry.compactDiskCenter.dx * s,
      TravelBannerGeometry.compactDiskCenter.dy * s,
    );
    canvas.drawCircle(
      diskC,
      diskR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            const Color(0xFF9EC8FF).withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: diskC, radius: diskR)),
    );

    // Wide translucent route band under the dashes (depth / motion).
    final softPath = Path()
      ..addArc(Rect.fromCircle(center: c, radius: arcR), start, sweep);
    canvas.drawPath(
      softPath,
      Paint()
        ..color = const Color(0x73D8F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = TravelBannerGeometry.compactSoftArcWidth * s
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * s),
    );
    canvas.drawPath(
      softPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = TravelBannerGeometry.compactSoftArcWidth * 0.62 * s
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
    );

    // Dashed route — large radius, marker in the lower-left of the sweep.
    final dashPath = Path()
      ..addArc(Rect.fromCircle(center: c, radius: arcR), start, sweep);
    _drawThinDashes(
      canvas,
      dashPath,
      color: SettingsColors.arcStroke.withValues(alpha: 0.72),
      strokeWidth: TravelBannerGeometry.compactArcStroke * s,
      dash: TravelBannerGeometry.compactArcDash * s,
      gap: TravelBannerGeometry.compactArcGap * s,
    );

    const polar = TravelBannerGeometry.compactMarkerPolarDeg * math.pi / 180;
    final markerPos = Offset(
      c.dx + arcR * math.cos(polar),
      c.dy + arcR * math.sin(polar),
    );
    // Tangent for CCW travel (negative sweep): opposite of CW unit tangent.
    final tangent = Offset(math.sin(polar), -math.cos(polar));
    final rotation = math.atan2(tangent.dx, -tangent.dy);
    _drawNavCursor(canvas, markerPos, rotation, scale: s * 2.15);
  }

  void _paintHero(Canvas canvas, Size size) {
    final c = TravelBannerGeometry.centerFor(size, TravelBannerLayout.hero);
    final sx = size.width / TravelBannerGeometry.heroDesignSize.width;
    final diskR = TravelBannerGeometry.diskRadius * sx;
    final midR = TravelBannerGeometry.trackMidRadius * sx;
    final glowR = TravelBannerGeometry.glowRadius * sx;
    final markerR = TravelBannerGeometry.markerRadius * sx;
    final glowCenter = Offset(
      c.dx + TravelBannerGeometry.glowOffsetFromCenter.dx * sx,
      c.dy + TravelBannerGeometry.glowOffsetFromCenter.dy * sx,
    );
    canvas.drawCircle(
      glowCenter,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowR)),
    );
    canvas.drawCircle(
      c,
      diskR,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    final arcPath = Path()
      ..addArc(Rect.fromCircle(center: c, radius: midR), math.pi, math.pi / 2);
    _drawThinDashes(
      canvas,
      arcPath,
      color: SettingsColors.arcStroke,
      strokeWidth: TravelBannerGeometry.arcStrokeWidth * sx,
      dash: TravelBannerGeometry.arcDash * sx,
      gap: TravelBannerGeometry.arcGap * sx,
    );
    const polar = TravelBannerGeometry.markerPolarDegrees * math.pi / 180;
    final markerPos = Offset(
      c.dx + markerR * math.cos(polar),
      c.dy + markerR * math.sin(polar),
    );
    final tangent = Offset(-math.sin(polar), math.cos(polar));
    _drawNavCursor(
      canvas,
      markerPos,
      math.atan2(tangent.dx, -tangent.dy),
      scale: sx,
    );
  }

  static void _drawThinDashes(
    Canvas canvas,
    Path path, {
    required Color color,
    required double strokeWidth,
    required double dash,
    required double gap,
  }) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), stroke);
        distance = next + gap;
      }
    }
  }

  static void _drawNavCursor(
    Canvas canvas,
    Offset center,
    double angle, {
    double scale = 1,
  }) {
    final paint = Paint()
      ..color = SettingsColors.cursorFill
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Figma Vector ≈14.6×12.7 — nav cursor, nose up, V-notch at base.
    final w = 7.3 * scale;
    final h = 6.35 * scale;
    final path = Path()
      ..moveTo(0, -h)
      ..lineTo(w, h)
      ..lineTo(0, h * 0.45)
      ..lineTo(-w, h)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TravelBannerDecorPainter oldDelegate) =>
      oldDelegate.layout != layout;
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
          stops: SettingsColors.bannerGradientStops,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _TravelBannerDecorPainter(
                layout: TravelBannerLayout.hero,
              ),
            ),
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
