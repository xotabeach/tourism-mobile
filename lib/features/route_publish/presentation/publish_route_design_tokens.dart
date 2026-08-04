import 'package:flutter/material.dart';

abstract final class PublishRouteDesignTokens {
  static const designWidth = 434.0;
  static const background = Color(0xFFF7F7F7);
  static const surface = Color(0xFFFFFFFF);
  static const dark = Color(0xFF212121);
  static const primaryBlue = Color(0xFF1E71CA);
  static const selectedLightBlue = Color(0xFFE6EDF4);
  static const fieldBackground = Color(0xFFE7E7E7);
  static const border = Color(0xFFD3D3D3);
  static const secondaryText = Color(0xFF8C8C8C);
  static const mediumText = Color(0xFF666666);
  static const disabledIcon = Color(0xFFD3D3D3);
  static const error = Color(0xFFB3261E);

  static TextStyle rubik({
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double height = 1,
  }) {
    return TextStyle(
      fontFamily: 'Rubik',
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }
}
