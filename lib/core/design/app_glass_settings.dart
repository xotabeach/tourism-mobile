/// «Жидкое стекло» в настройках (iOS only) — см.
/// `LiquidGlassPreferenceController`. Плоское статическое поле, а не
/// провайдер: кнопки в core/design — простые StatelessWidget и не должны
/// становиться Consumer ради одного флага. [TourismApp] держит
/// `ref.watch(liquidGlassEnabledProvider)` в корне, чтобы смена настройки
/// перестраивала всё дерево — тот же приём, что и для `reduceMotion`.
///
/// Живёт отдельно от `components/app_glass.dart`, потому что читается ещё и
/// из `core/performance/app_perf.dart`, который не должен зависеть от
/// виджетов.
abstract final class AppGlassSettings {
  static bool enabled = true;
}
