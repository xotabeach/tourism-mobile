import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration emphasized = Duration(milliseconds: 260);
  static const Duration modeMorph = Duration(milliseconds: 420);
  // Shell-chrome timings are matched against a 60 fps capture of the iOS 26
  // Liquid Glass tab bar: indicator travel ~100 ms, collapse/expand ~230 ms,
  // search morph ~250 ms. Anything slower reads as sluggish next to it.
  static const Duration composeMorph = Duration(milliseconds: 280);
  static const Duration composeClose = Duration(milliseconds: 220);
  static const Duration droplet = Duration(milliseconds: 140);
  static const Duration detailMorph = Duration(milliseconds: 280);

  /// Active-icon tint crossfade. Deliberately much shorter than [droplet] —
  /// on the reference capture the tint lands in ~3 frames, well before the
  /// indicator finishes travelling.
  static const Duration navTint = Duration(milliseconds: 70);
  static const Duration reduced = Duration(milliseconds: 150);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const Curve modeMorphCurve = Cubic(0.22, 0.78, 0.2, 1);
  static const Curve liquidOut = Cubic(0.16, 0.82, 0.18, 1);

  /// Indicator travel between destinations: quick departure, decelerating
  /// settle — the shape of the spring the reference tab bar uses. Distinct
  /// from [liquidOut], which is far more front-loaded (77% of the distance in
  /// the first quarter) and turns a slot-to-slot jump into a teleport.
  static const Curve navTravel = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static const double springMass = 1;
  static const double springStiffness = 330;
  static const double springDamping = 26;
}
