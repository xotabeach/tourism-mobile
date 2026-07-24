import 'package:flutter/material.dart';

/// Brand typefaces. Logo uses Rubik (bundled under assets/fonts).
abstract final class AppFonts {
  static const rubik = 'Rubik';
}

abstract final class AppTextStyles {
  /// Wordmark «КРЫМТРИП».
  static TextStyle logo({
    Color? color,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: AppFonts.rubik,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 2.2,
      height: 1.2,
      color: color,
      fontVariations: [FontVariation('wght', _wght(fontWeight))],
    );
  }

  static double _wght(FontWeight weight) {
    return weight.value.toDouble();
  }
}
