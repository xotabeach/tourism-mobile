import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x16000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x19000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> deck = [
    BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
}
