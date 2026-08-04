import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';

/// Pixel tokens for «Построй маршрут» (base width 393 logical px).
abstract final class RouteBuilderDesignTokens {
  static const double designWidth = 393.0;
  static const double maxContentWidth = 440.0;

  static const Color background = Color(0xFFF7F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryBlue = Color(0xFF1E71CA);
  static const Color deepBlue = Color(0xFF2558FF);
  static const Color cyanBlue = Color(0xFF5CC5E7);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF8C8C8C);
  static const Color fieldBackground = Color(0xFFE7E7E7);
  static const Color borderGray = Color(0xFFD3D3D3);
  static const Color lightBorder = Color(0xFFE7E7E7);
  static const Color selectedLightBlue = Color(0xFFE6EDF4);
  static const Color divider = Color(0xFFCCCCCC);
  static const Color chipBorder = Color(0xFFE0E0E0);
  static const Color chipText = Color(0xFF666666);
  static const Color interestBorder = Color(0xFFDCDCDC);
  static const Color searchIcon = Color(0xFFA7A7A7);
  static const Color aiCaption = Color(0xFFB8CBE7);
  static const Color agentTimestamp = Color(0xFFE7E7E7);

  /// Same fill as Travel+ settings banner (`#90D3EB` → `#547BFC` @ 68%).
  static const Color travelPlusGradientStart = Color(0xFF90D3EB);
  static const Color travelPlusGradientEnd = Color(0xFF547BFC);
  static const Alignment travelPlusGradientEndAlign = Alignment(1.0, 0.18);
  static const List<double> travelPlusGradientStops = [0.0, 0.68];

  static const List<Color> agentBorderGradient = [
    Color(0xFF2558FF),
    Color(0xFF63CBFF),
    Color(0xFF3474FF),
    Color(0xFF2558FF),
  ];

  static LinearGradient get travelPlusGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: travelPlusGradientEndAlign,
    colors: [travelPlusGradientStart, travelPlusGradientEnd],
    stops: travelPlusGradientStops,
  );

  /// Alias used by AI CTA / send / mode chip.
  static LinearGradient get actionLinearGradient => travelPlusGradient;

  static TextStyle rubik({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.0,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
      // Rubik already tracks wide; keep default 0 unless the frame asks.
      letterSpacing: letterSpacing,
    );
  }
}

/// Scale helper scoped to the route-builder screen width.
final class RouteBuilderScale {
  RouteBuilderScale(this.scale);

  factory RouteBuilderScale.of(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = screenWidth > RouteBuilderDesignTokens.maxContentWidth
        ? RouteBuilderDesignTokens.maxContentWidth
        : screenWidth;
    return RouteBuilderScale(width / RouteBuilderDesignTokens.designWidth);
  }

  final double scale;

  double px(double value) => value * scale;
}

/// Removes Material overscroll glow / stretch indicators.
final class RouteBuilderScrollBehavior extends ScrollBehavior {
  const RouteBuilderScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
