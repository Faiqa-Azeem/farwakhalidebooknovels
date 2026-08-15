import Flutter
import GoogleMobileAds
import UIKit

/// Presents interstitial and rewarded ads via the Google Mobile Ads iOS SDK,
/// bypassing the Flutter plugin's full-screen presentation path on iOS.
final class NativeAdManager: NSObject {
  static let shared = NativeAdManager()

  private let channelName = "com.farwa.farwa_khalid/native_ads"

  private var interstitial: InterstitialAd?
  private var rewarded: RewardedAd?

  private var isFullScreenAdShowing = false
  private var rewardEarned = false
  private var activeAdKind: ActiveAdKind = .none
  private var pendingShowResult: FlutterResult?

  private enum ActiveAdKind {
    case none
    case interstitial
    case rewarded
  }

  private override init() {
    super.init()
  }

  func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadInterstitial":
      guard let args = call.arguments as? [String: Any],
            let adUnitId = args["adUnitId"] as? String,
            !adUnitId.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "adUnitId required", details: nil))
        return
      }
      loadInterstitial(adUnitId: adUnitId, result: result)

    case "showInterstitial":
      showInterstitial(result: result)

    case "loadRewarded":
      guard let args = call.arguments as? [String: Any],
            let adUnitId = args["adUnitId"] as? String,
            !adUnitId.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "adUnitId required", details: nil))
        return
      }
      loadRewarded(adUnitId: adUnitId, result: result)

    case "showRewarded":
      showRewarded(result: result)

    case "isFullScreenAdShowing":
      result(isFullScreenAdShowing)

    case "disposeInterstitial":
      interstitial = nil
      result(nil)

    case "disposeRewarded":
      rewarded = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Load

  private func loadInterstitial(adUnitId: String, result: @escaping FlutterResult) {
    if isFullScreenAdShowing {
      result(false)
      return
    }

    interstitial = nil
    InterstitialAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
      DispatchQueue.main.async {
        guard let self else {
          result(false)
          return
        }
        if let error {
          self.logDebug("interstitial load failed: \(error.localizedDescription)")
          self.interstitial = nil
          result(false)
          return
        }
        guard let ad else {
          self.interstitial = nil
          result(false)
          return
        }
        ad.fullScreenContentDelegate = self
        self.interstitial = ad
        self.logDebug("interstitial loaded")
        result(true)
      }
    }
  }

  private func loadRewarded(adUnitId: String, result: @escaping FlutterResult) {
    if isFullScreenAdShowing {
      result(false)
      return
    }

    rewarded = nil
    RewardedAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
      DispatchQueue.main.async {
        guard let self else {
          result(false)
          return
        }
        if let error {
          self.logDebug("rewarded load failed: \(error.localizedDescription)")
          self.rewarded = nil
          result(false)
          return
        }
        guard let ad else {
          self.rewarded = nil
          result(false)
          return
        }
        ad.fullScreenContentDelegate = self
        self.rewarded = ad
        self.logDebug("rewarded loaded")
        result(true)
      }
    }
  }

  // MARK: - Show

  private func showInterstitial(result: @escaping FlutterResult) {
    if isFullScreenAdShowing {
      logDebug("show blocked: native lock held")
      result("alreadyShowing")
      return
    }

    guard let ad = interstitial else {
      result("notReady")
      return
    }

    guard let presenter = resolveFlutterViewController() else {
      logDebug("show failed: no active FlutterViewController")
      result("failed")
      return
    }

    if !canPresent(from: presenter) {
      result("failed")
      return
    }

    interstitial = nil
    pendingShowResult = result
    activeAdKind = .interstitial
    isFullScreenAdShowing = true
    rewardEarned = false

    logPresentationContext(presenter: presenter, kind: "interstitial")

    ad.fullScreenContentDelegate = self
    ad.present(from: presenter)
  }

  private func showRewarded(result: @escaping FlutterResult) {
    if isFullScreenAdShowing {
      logDebug("show blocked: native lock held")
      result("alreadyShowing")
      return
    }

    guard let ad = rewarded else {
      result("notReady")
      return
    }

    guard let presenter = resolveFlutterViewController() else {
      logDebug("show failed: no active FlutterViewController")
      result("failed")
      return
    }

    if !canPresent(from: presenter) {
      result("failed")
      return
    }

    rewarded = nil
    pendingShowResult = result
    activeAdKind = .rewarded
    isFullScreenAdShowing = true
    rewardEarned = false

    logPresentationContext(presenter: presenter, kind: "rewarded")

    ad.fullScreenContentDelegate = self
    ad.present(from: presenter) {
      self.rewardEarned = true
      self.logDebug("reward earned (waiting for dismissal)")
    }
  }

  // MARK: - Presenter resolution

  private func resolveFlutterViewController() -> FlutterViewController? {
    let activeScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    guard let windowScene = activeScenes.first else {
      logDebug("no foregroundActive UIWindowScene")
      return nil
    }

    let window = windowScene.windows.first(where: { $0.isKeyWindow })
      ?? windowScene.windows.first(where: { !$0.isHidden && $0.alpha > 0 })
      ?? windowScene.windows.first

    guard let root = window?.rootViewController else {
      logDebug("no rootViewController on active window")
      return nil
    }

    return findFlutterViewController(from: root)
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

    if let presented = viewController.presentedViewController,
       !presented.isBeingDismissed {
      return findFlutterViewController(from: presented)
    }

    return nil
  }

  private func canPresent(from flutterVC: FlutterViewController) -> Bool {
    if let presented = flutterVC.presentedViewController,
       !presented.isBeingDismissed {
      logDebug(
        "unsafe presentation: FlutterViewController already presenting \(String(describing: type(of: presented)))"
      )
      return false
    }
    return true
  }

  // MARK: - Completion

  private func completeShow(with resultValue: String) {
    let flutterResult = pendingShowResult
    pendingShowResult = nil
    activeAdKind = .none
    isFullScreenAdShowing = false
    rewardEarned = false

    logDebug("lock released")
    logDebug("result returned to Flutter: \(resultValue)")

    if let presenter = resolveFlutterViewController() {
      let presented = presenter.presentedViewController
      logDebug(
        "presented VC after dismissal = \(presented.map { String(describing: type(of: $0)) } ?? "nil")"
      )
      if presented != nil {
        logDebug("suspicious: unexpected presented controller remains after ad dismissal")
      }
    }

    flutterResult?(resultValue)
  }

  private func clearActiveAdReference() {
    switch activeAdKind {
    case .interstitial:
      interstitial = nil
    case .rewarded:
      rewarded = nil
    case .none:
      break
    }
  }

  // MARK: - Logging

  private func logPresentationContext(presenter: FlutterViewController, kind: String) {
    let presented = presenter.presentedViewController
    logDebug("presenter = \(String(describing: type(of: presenter)))")
    logDebug(
      "currently presented VC = \(presented.map { String(describing: type(of: $0)) } ?? "nil")"
    )
    logDebug("showing \(kind)")
  }

  private func logDebug(_ message: String) {
    #if DEBUG
    print("[NATIVE_AD] \(message)")
    #endif
  }
}

// MARK: - FullScreenContentDelegate

extension NativeAdManager: FullScreenContentDelegate {
  func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
    logDebug("will present full screen content")
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    logDebug("dismissal callback")

    let kind = activeAdKind
    clearActiveAdReference()

    switch kind {
    case .interstitial:
      completeShow(with: "dismissed")
    case .rewarded:
      completeShow(with: rewardEarned ? "rewarded" : "dismissed")
    case .none:
      isFullScreenAdShowing = false
      rewardEarned = false
      logDebug("dismissal with no active ad kind")
    }
  }

  func ad(
    _ ad: FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: Error
  ) {
    logDebug("presentation failed: \(error.localizedDescription)")
    clearActiveAdReference()
    completeShow(with: "failed")
  }
}
