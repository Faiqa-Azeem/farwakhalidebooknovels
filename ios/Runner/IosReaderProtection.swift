import Flutter
import UIKit

/// Blocks screenshots and screen recording on the Flutter reader view only.
///
/// Unlike the screen_protector plugin, this does NOT register UIApplication
/// lifecycle hooks or manipulate UIWindow on resign-active (which broke Flutter
/// rendering after full-screen ad dismissal).
final class IosReaderProtection: NSObject {
  static let shared = IosReaderProtection()

  private let channelName = "com.farwa.farwa_khalid/reader_protection"

  private var secureField: UITextField?
  private weak var protectedView: UIView?
  private weak var previousSuperlayer: CALayer?

  private var isEnabled = false

  private override init() {
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enable":
      enableProtection(result: result)
    case "disable":
      disableProtection(result: result)
    case "isEnabled":
      result(isEnabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enableProtection(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(false)
        return
      }
      guard let flutterView = self.resolveFlutterView() else {
        self.logDebug("enable failed: Flutter view not found")
        result(false)
        return
      }
      self.applySecureLayer(to: flutterView)
      self.isEnabled = true
      self.logDebug("reader protection enabled")
      result(true)
    }
  }

  private func disableProtection(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(nil)
        return
      }
      self.removeSecureLayer()
      self.isEnabled = false
      self.logDebug("reader protection disabled")
      result(nil)
    }
  }

  private func applySecureLayer(to view: UIView) {
    removeSecureLayer()

    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    field.backgroundColor = .clear
    field.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(field)
    NSLayoutConstraint.activate([
      field.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      field.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      field.topAnchor.constraint(equalTo: view.topAnchor),
      field.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    view.layoutIfNeeded()

    guard let fieldSecureLayer = field.layer.sublayers?.first else {
      field.removeFromSuperview()
      return
    }

    previousSuperlayer = view.layer.superlayer
    previousSuperlayer?.addSublayer(fieldSecureLayer)
    fieldSecureLayer.addSublayer(view.layer)

    secureField = field
    protectedView = view
  }

  private func removeSecureLayer() {
    if let view = protectedView, let superlayer = previousSuperlayer {
      view.layer.removeFromSuperlayer()
      superlayer.addSublayer(view.layer)
    }
    secureField?.removeFromSuperview()
    secureField = nil
    protectedView = nil
    previousSuperlayer = nil
  }

  private func resolveFlutterView() -> UIView? {
    let activeScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    guard let windowScene = activeScenes.first else { return nil }

    let window = windowScene.windows.first(where: { $0.isKeyWindow })
      ?? windowScene.windows.first(where: { !$0.isHidden && $0.alpha > 0 })
      ?? windowScene.windows.first

    guard let root = window?.rootViewController else { return nil }
    return findFlutterViewController(from: root)?.view
  }

  private func findFlutterViewController(from viewController: UIViewController) -> FlutterViewController? {
    if let flutterVC = viewController as? FlutterViewController {
      return flutterVC
    }
    if let navigationController = viewController as? UINavigationController,
       let visible = navigationController.visibleViewController {
      return findFlutterViewController(from: visible)
    }
    if let tabBarController = viewController as? UITabBarController,
       let selected = tabBarController.selectedViewController {
      return findFlutterViewController(from: selected)
    }
    return nil
  }

  private func logDebug(_ message: String) {
    #if DEBUG
    print("[READER_PROTECTION] \(message)")
    #endif
  }
}
