import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration emphasized = Duration(milliseconds: 260);
  static const Duration modeMorph = Duration(milliseconds: 420);
  static const Duration composeMorph = Duration(milliseconds: 620);
  static const Duration composeClose = Duration(milliseconds: 360);
  static const Duration droplet = Duration(milliseconds: 360);
  static const Duration detailMorph = Duration(milliseconds: 720);
  static const Duration reduced = Duration(milliseconds: 150);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const Curve modeMorphCurve = Cubic(0.22, 0.78, 0.2, 1);
  static const Curve liquidOut = Cubic(0.16, 0.82, 0.18, 1);
  static const Curve spring = Curves.easeOutBack;

  static const double springMass = 1;
  static const double springStiffness = 330;
  static const double springDamping = 26;
}
