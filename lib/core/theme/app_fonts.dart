import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';

export 'package:tourism_mobile/core/design/app_typography.dart' show AppFonts;

abstract final class AppTextStyles {
  /// Wordmark «КРЫМТРИП».
  static TextStyle logo({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 2.6,
      height: 1.2,
      color: color,
    );
  }

  /// Large titles (ЗДРАВСТВУЙ, ПОСТРОЙ МАРШРУТ…) — Rubik SemiBold.
  static TextStyle displayTitle({
    Color color = const Color(0xFF111111),
    double fontSize = 40,
    double height = 1.08,
  }) {
    return TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: height,
      letterSpacing: 0.4,
      color: color,
    );
  }
}
