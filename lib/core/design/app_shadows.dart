import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: Color(0x16000000),
      blurRadius: 20,
      spreadRadius: -3,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 18,
      spreadRadius: -3,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> tile = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> deck = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 24,
      spreadRadius: -4,
      offset: Offset(0, 12),
    ),
  ];

  /// Settings rows / cards: soft lift below + light side bloom.
  static const List<BoxShadow> settingsTile = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 10,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0C000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset.zero,
    ),
  ];

  /// Travel+ banner / active support row — same language, a touch stronger.
  static const List<BoxShadow> settingsElevated = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 5),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 8,
      spreadRadius: -1,
      offset: Offset.zero,
    ),
  ];
}
