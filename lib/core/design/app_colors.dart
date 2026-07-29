import 'package:flutter/material.dart';

/// Central color tokens for the CrimeTrip light experience.
abstract final class AppColors {
  static const Color seed = Color(0xFF171719);

  static const Color pageSurface = Color(0xFFF7F7F7);
  static const Color elevatedSurface = Color(0xFFFFFFFF);
  static const Color primaryInk = Color(0xFF171719);
  static const Color secondaryInk = Color(0xFF77797E);

  /// Flat fill of search, filter and icon controls on the page surface.
  static const Color controlSurface = Color(0xFFE7E7E7);
  static const Color hairline = Color(0xFFE3E3E5);

  static const Color glassFill = Color(0x99F4F4F6);
  static const Color glassFillStrong = Color(0xC7F4F4F6);
  static const Color glassBorder = Color(0xB8FFFFFF);
  static const Color glassHighlight = Color(0x70FFFFFF);

  static const Color activeNavigationFill = Color(0xFF1C1C1E);
  static const Color inactiveNavigationIcon = Color(0xFF77797D);

  static const Color positiveSwipeTint = Color(0xFF294638);
  static const Color negativeSwipeTint = Color(0xFF563837);
  static const Color imageScrim = Color(0xFF111113);

  static const Color focus = Color(0xFF1B6B93);
  static const Color error = Color(0xFFB3261E);
  static const Color rating = Color(0xFFFFD21E);

  /// Settings / Travel+ accent from Figma pixel spec (`#386FC4`).
  static const Color accentBlue = Color(0xFF386FC4);

  /// Outline icons + link blue on settings screens (`#2F6FD0`).
  static const Color accentBlueIcon = Color(0xFF2F6FD0);

  /// Primary ink on settings rows / section titles (`#212121`).
  static const Color settingsInk = Color(0xFF212121);

  /// Secondary captions on settings rows (`#909090`).
  static const Color settingsSecondaryInk = Color(0xFF909090);

  /// Brand mark in settings headers (`#8C8C8C`).
  static const Color settingsBrand = Color(0xFF8C8C8C);

  // Compatibility aliases for existing screens.
  static const Color ink = primaryInk;
  static const Color inkSoft = secondaryInk;
  static const Color mist = pageSurface;
  static const Color mistDark = Color(0xFFE5E5E8);
  static const Color glass = glassFillStrong;
  static const Color sea = focus;
  static const Color coastline = Color(0xFF0E4D6B);
  static const Color sand = Color(0xFFF3E6D4);
  static const Color cliff = Color(0xFF5C4A3A);
  static const Color sunsetTop = Color(0xFF2A1B3D);
  static const Color sunsetMid = Color(0xFFC45C3E);
  static const Color sunsetBottom = Color(0xFF1A2A3A);
}
