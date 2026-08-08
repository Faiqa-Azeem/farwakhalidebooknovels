import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.farwa.farwa_khalid/surface_recovery",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "recoverSurface" else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.main.async {
          self?.recoverFlutterSurface(controller: controller)
          result(true)
        }
      }
    }

    return result
  }

  /// Forces the Flutter Metal surface to redraw after a native full-screen ad closes.
  private func recoverFlutterSurface(controller: FlutterViewController) {
    guard let view = controller.view else { return }

    view.isHidden = true
    view.backgroundColor = UIColor.white
    view.setNeedsLayout()
    view.layoutIfNeeded()
    view.isHidden = false
    view.setNeedsDisplay()

    view.layer.setNeedsDisplay()
    view.layer.displayIfNeeded()

    NotificationCenter.default.post(
      name: UIApplication.didBecomeActiveNotification,
      object: UIApplication.shared
    )
  }
}
