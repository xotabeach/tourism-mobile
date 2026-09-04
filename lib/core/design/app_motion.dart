import 'package:flutter/animation.dart';

abstract final class AppMotion {
  /// «Меньше анимаций» из настроек. Все длительности ниже — геттеры, которые
  /// смотрят на этот флаг: иначе пришлось бы протаскивать настройку в сотню
  /// мест, и любое новое из них про неё забыло бы.
  ///
  /// Кривые и параметры пружины остаются: при нулевой длительности они ни на
  /// что не влияют, а код, который их читает, не должен ветвиться.
  static bool reduceMotion = false;

  static Duration _scaled(Duration base) => reduceMotion ? Duration.zero : base;

  static Duration get fast => _scaled(const Duration(milliseconds: 120));
  static Duration get normal => _scaled(const Duration(milliseconds: 180));
  static Duration get emphasized => _scaled(const Duration(milliseconds: 260));
  static Duration get modeMorph => _scaled(const Duration(milliseconds: 420));
  // Shell-chrome timings are matched against a 60 fps capture of the iOS 26
  // Liquid Glass tab bar: indicator travel ~100 ms, collapse/expand ~230 ms,
  // search morph ~250 ms. Anything slower reads as sluggish next to it.
  static Duration get composeMorph =>
      _scaled(const Duration(milliseconds: 280));
  static Duration get composeClose =>
      _scaled(const Duration(milliseconds: 220));
  static Duration get droplet => _scaled(const Duration(milliseconds: 140));
  static Duration get detailMorph => _scaled(const Duration(milliseconds: 280));

  /// Active-icon tint crossfade. Deliberately much shorter than [droplet] —
  /// on the reference capture the tint lands in ~3 frames, well before the
  /// indicator finishes travelling.
  static Duration get navTint => _scaled(const Duration(milliseconds: 70));
  static Duration get reduced => _scaled(const Duration(milliseconds: 150));

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
