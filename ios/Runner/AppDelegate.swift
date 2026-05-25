import Flutter
import UIKit
import AppTrackingTransparency

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request App Tracking Transparency natively (no CocoaPods plugin needed).
    // Deferred so the scene is active when the system prompt is shown.
    if #available(iOS 14, *) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        ATTrackingManager.requestTrackingAuthorization { _ in }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
