import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x16000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x19000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> tile = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> deck = [
    BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 12)),
  ];

  /// White settings cards: rgba(0,0,0,0.06) / 0,2 / blur 8.
  static const List<BoxShadow> settingsTile = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Travel+ banner / active support row: rgba(0,0,0,0.10) / 0,4 / blur 12.
  static const List<BoxShadow> settingsElevated = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
