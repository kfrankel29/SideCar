import Flutter
import GoogleMaps
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if
      let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
      !mapsAPIKey.isEmpty
    {
      GMSServices.provideAPIKey(mapsAPIKey)
    }
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
      if call.method == "consumeFreshInstall" {
        let key = "sidecar.install.registered"
        let defaults = UserDefaults.standard
        let isFreshInstall = !defaults.bool(forKey: key)
        if isFreshInstall {
          defaults.set(true, forKey: key)
        }
        result(isFreshInstall)
        return
      }

      if call.method == "requestAppReview" {
        DispatchQueue.main.async {
          if
            #available(iOS 14.0, *),
            let scene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .first(where: { $0.activationState == .foregroundActive })
          {
            SKStoreReviewController.requestReview(in: scene)
            result(true)
          } else {
            SKStoreReviewController.requestReview()
            result(true)
          }
        }
        return
      }

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
