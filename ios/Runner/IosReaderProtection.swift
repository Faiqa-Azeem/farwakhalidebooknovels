import Flutter
import UIKit

/// Reader-only content protection for iOS without reparenting Flutter layers.
///
/// Layer reparenting (used by screen_protector) crashes Impeller after ads.
/// This implementation:
/// - blocks screen recording by covering content while capture is active
/// - adds a non-destructive secure overlay to reduce screenshot leakage
/// - never moves FlutterView.layer in the hierarchy
final class IosReaderProtection: NSObject {
  static let shared = IosReaderProtection()

  private let channelName = "com.farwa.farwa_khalid/reader_protection"

  private var secureOverlay: UITextField?
  private var captureBlocker: UIView?
  private weak var hostView: UIView?
  private var observers: [NSObjectProtocol] = []
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
      self.startProtection(on: flutterView)
      self.isEnabled = true
      self.logDebug("reader protection enabled (safe mode)")
      result(true)
    }
  }

  private func disableProtection(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      self?.stopProtection()
      result(nil)
    }
  }

  private func startProtection(on view: UIView) {
    stopProtection()
    hostView = view

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

    secureOverlay = field

    let captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.syncCaptureBlocker()
    }
    observers.append(captureObserver)

    if #available(iOS 11.0, *) {
      let screenshotObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.userDidTakeScreenshotNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.flashCaptureBlocker()
      }
      observers.append(screenshotObserver)
    }

    syncCaptureBlocker()
  }

  private func stopProtection() {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()

    captureBlocker?.removeFromSuperview()
    captureBlocker = nil

    secureOverlay?.removeFromSuperview()
    secureOverlay = nil

    hostView = nil
    isEnabled = false
    logDebug("reader protection disabled")
  }

  private func syncCaptureBlocker() {
    guard isEnabled else { return }

    if UIScreen.main.isCaptured {
      showCaptureBlocker()
    } else {
      hideCaptureBlocker()
    }
  }

  private func showCaptureBlocker() {
    guard captureBlocker == nil else { return }
    guard let view = hostView ?? resolveFlutterView() else { return }

    let blocker = UIView()
    blocker.backgroundColor = .black
    blocker.isUserInteractionEnabled = true
    blocker.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(blocker)
    NSLayoutConstraint.activate([
      blocker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      blocker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      blocker.topAnchor.constraint(equalTo: view.topAnchor),
      blocker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    captureBlocker = blocker
    logDebug("screen recording blocked with overlay")
  }

  private func hideCaptureBlocker() {
    captureBlocker?.removeFromSuperview()
    captureBlocker = nil
  }

  private func flashCaptureBlocker() {
    guard isEnabled else { return }
    showCaptureBlocker()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      guard let self, self.isEnabled, !UIScreen.main.isCaptured else { return }
      self.hideCaptureBlocker()
    }
    logDebug("screenshot detected — brief content cover")
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
