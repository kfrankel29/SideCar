import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SideCarSettings") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.kaileefrankel.sidecar/settings",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openAppSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
        return
      }
      UIApplication.shared.open(url) { opened in
        opened ? result(nil) : result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
      }
    }
  }
}
