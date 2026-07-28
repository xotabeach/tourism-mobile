import Flutter
import UIKit

/// Registers the thin Liquid Glass platform view used as an iOS chrome backdrop.
enum LiquidGlassPlugin {
  static let viewTypeId = "crimeatrip/liquid_glass"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LiquidGlassPlugin") else {
      return
    }
    let factory = LiquidGlassPlatformViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: viewTypeId)
  }
}

final class LiquidGlassPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> any FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> any FlutterPlatformView {
    LiquidGlassPlatformView(frame: frame, arguments: args)
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, arguments args: Any?) {
    container = LiquidGlassContainerView(frame: frame, arguments: args)
    super.init()
  }

  func view() -> UIView {
    container
  }
}

final class LiquidGlassContainerView: UIView {
  private let effectView: UIVisualEffectView
  private var cornerRadius: CGFloat = 22
  private var isCircle = false

  init(frame: CGRect, arguments args: Any?) {
    let params = args as? [String: Any] ?? [:]
    cornerRadius = CGFloat((params["cornerRadius"] as? NSNumber)?.doubleValue ?? 22)
    let shape = (params["shape"] as? String) ?? "rect"
    isCircle = shape == "circle"
    let interactive = (params["interactive"] as? NSNumber)?.boolValue ?? false

    // Start without an animated effect transition — UIGlassEffect otherwise
    // morphs in and reads as flicker under Flutter route pushes.
    effectView = UIVisualEffectView(effect: nil)
    super.init(frame: frame)

    clipsToBounds = true
    isUserInteractionEnabled = false
    backgroundColor = UIColor.secondarySystemFill
    effectView.isUserInteractionEnabled = false
    effectView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(effectView)
    NSLayoutConstraint.activate([
      effectView.topAnchor.constraint(equalTo: topAnchor),
      effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
      effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
    applyShape()
    UIView.performWithoutAnimation {
      self.effectView.effect = Self.makeEffect(interactive: interactive)
      self.layoutIfNeeded()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    applyShape()
  }

  private func applyShape() {
    let radius = isCircle ? min(bounds.width, bounds.height) / 2 : cornerRadius
    layer.cornerRadius = radius
    layer.cornerCurve = .continuous
    effectView.layer.cornerRadius = radius
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
  }

  private static func makeEffect(interactive: Bool) -> UIVisualEffect {
    if UIAccessibility.isReduceTransparencyEnabled {
      return UIBlurEffect(style: .systemMaterial)
    }
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect()
      // Interactive glass picks up press/highlight lighting when the host control
      // is interactive; the view itself stays non-hit-testable so Flutter owns taps.
      if interactive {
        glass.isInteractive = true
      }
      return glass
    }
    return UIBlurEffect(style: .systemMaterial)
  }
}
