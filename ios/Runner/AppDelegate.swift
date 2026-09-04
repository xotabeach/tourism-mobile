import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let settingsChannelName = "com.crimeatravel.tourism_mobile/settings"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LiquidGlassPlugin.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterMethodChannel(
      name: Self.settingsChannelName,
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "openNotificationSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "setAppIcon":
        // Стандартная иконка на iOS задаётся значением nil, а не именем:
        // альтернативные объявлены в Info.plist, основная — в каталоге ассетов.
        let variant = (call.arguments as? [String: Any])?["variant"] as? String
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(
            code: "unsupported",
            message: "Смена иконки недоступна на этом устройстве",
            details: nil
          ))
          return
        }
        let name: String? = (variant == nil || variant == "default") ? nil : variant
        UIApplication.shared.setAlternateIconName(name) { error in
          if let error {
            result(FlutterError(
              code: "icon_failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      case "currentAppIcon":
        result(UIApplication.shared.alternateIconName ?? "default")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
