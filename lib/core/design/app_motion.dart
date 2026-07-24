import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration emphasized = Duration(milliseconds: 260);
  static const Duration droplet = Duration(milliseconds: 360);
  static const Duration reduced = Duration(milliseconds: 150);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const Curve spring = Curves.easeOutBack;

  static const double springMass = 1;
  static const double springStiffness = 330;
  static const double springDamping = 26;
}
