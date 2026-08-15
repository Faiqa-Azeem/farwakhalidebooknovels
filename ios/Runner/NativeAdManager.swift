import Flutter
import GoogleMobileAds
import UIKit

/// Presents interstitial and rewarded ads via the Google Mobile Ads iOS SDK,
/// bypassing the Flutter plugin's full-screen presentation path on iOS.
final class NativeAdManager: NSObject {
  static let shared = NativeAdManager()

  private let channelName = "com.farwa.farwa_khalid/native_ads"

  private var loadedInterstitial: InterstitialAd?
  private var loadedRewarded: RewardedAd?
  private var presentingInterstitial: InterstitialAd?
  private var presentingRewarded: RewardedAd?

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
      disposeLoadedInterstitial(result: result)

    case "disposeRewarded":
      disposeLoadedRewarded(result: result)

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

    loadedInterstitial = nil
    InterstitialAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
      DispatchQueue.main.async {
        guard let self else {
          result(false)
          return
        }
        if self.isFullScreenAdShowing {
          result(false)
          return
        }
        if let error {
          self.logDebug("interstitial load failed: \(error.localizedDescription)")
          self.loadedInterstitial = nil
          result(false)
          return
        }
        guard let ad else {
          self.loadedInterstitial = nil
          result(false)
          return
        }
        ad.fullScreenContentDelegate = self
        self.loadedInterstitial = ad
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

    loadedRewarded = nil
    RewardedAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
      DispatchQueue.main.async {
        guard let self else {
          result(false)
          return
        }
        if self.isFullScreenAdShowing {
          result(false)
          return
        }
        if let error {
          self.logDebug("rewarded load failed: \(error.localizedDescription)")
          self.loadedRewarded = nil
          result(false)
          return
        }
        guard let ad else {
          self.loadedRewarded = nil
          result(false)
          return
        }
        ad.fullScreenContentDelegate = self
        self.loadedRewarded = ad
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

    guard let ad = loadedInterstitial else {
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

    loadedInterstitial = nil
    presentingInterstitial = ad
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

    guard let ad = loadedRewarded else {
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

    loadedRewarded = nil
    presentingRewarded = ad
    pendingShowResult = result
    activeAdKind = .rewarded
    isFullScreenAdShowing = true
    rewardEarned = false

    logPresentationContext(presenter: presenter, kind: "rewarded")

    ad.fullScreenContentDelegate = self
    ad.present(from: presenter) { [weak self] in
      self?.rewardEarned = true
      self?.logDebug("reward earned (waiting for dismissal)")
    }
  }

  // MARK: - Dispose (loaded only, never while presenting)

  private func disposeLoadedInterstitial(result: @escaping FlutterResult) {
    if isFullScreenAdShowing || presentingInterstitial != nil {
      logDebug("disposeInterstitial ignored: ad is presenting")
      result(nil)
      return
    }
    loadedInterstitial = nil
    result(nil)
  }

  private func disposeLoadedRewarded(result: @escaping FlutterResult) {
    if isFullScreenAdShowing || presentingRewarded != nil {
      logDebug("disposeRewarded ignored: ad is presenting")
      result(nil)
      return
    }
    loadedRewarded = nil
    result(nil)
  }

  // MARK: - Presenter resolution (read-only; never mutates hierarchy)

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

    DispatchQueue.main.async { [weak self] in
      self?.logFlutterSurfaceState()
    }
  }

  private func releasePresentingAd(for kind: ActiveAdKind) {
    switch kind {
    case .interstitial:
      presentingInterstitial = nil
    case .rewarded:
      presentingRewarded = nil
    case .none:
      break
    }
  }

  // MARK: - DEBUG surface observation (no manipulation)

  private func logFlutterSurfaceState() {
    #if DEBUG
    guard let flutterVC = resolveFlutterViewController() else {
      print("[FLUTTER_SURFACE] flutterVC = nil")
      return
    }

    let view = flutterVC.view
    let window = view.window
    let scene = window?.windowScene
    let sceneState = scene.map { String(describing: $0.activationState) } ?? "nil"
    let presented = flutterVC.presentedViewController
    let layerType = String(describing: type(of: view.layer))

    print("[FLUTTER_SURFACE] scene = \(sceneState)")
    print("[FLUTTER_SURFACE] window key = \(window?.isKeyWindow ?? false)")
    print("[FLUTTER_SURFACE] window hidden = \(window?.isHidden ?? true)")
    print("[FLUTTER_SURFACE] window alpha = \(window?.alpha ?? -1)")
    print("[FLUTTER_SURFACE] flutterVC = alive")
    print("[FLUTTER_SURFACE] flutterView window = \(view.window == nil ? "nil" : "alive")")
    print("[FLUTTER_SURFACE] flutterView hidden = \(view.isHidden)")
    print("[FLUTTER_SURFACE] flutterView alpha = \(view.alpha)")
    print("[FLUTTER_SURFACE] flutterView bounds = \(view.bounds)")
    print("[FLUTTER_SURFACE] presentedVC = \(presented.map { String(describing: type(of: $0)) } ?? "nil")")
    print("[FLUTTER_SURFACE] flutterView layer = \(layerType)")
    #endif
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
    releasePresentingAd(for: kind)

    switch kind {
    case .interstitial:
      completeShow(with: "dismissed")
    case .rewarded:
      completeShow(with: rewardEarned ? "rewarded" : "dismissed")
    case .none:
      isFullScreenAdShowing = false
      rewardEarned = false
      presentingInterstitial = nil
      presentingRewarded = nil
      logDebug("dismissal with no active ad kind")
    }
  }

  func ad(
    _ ad: FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: Error
  ) {
    logDebug("presentation failed: \(error.localizedDescription)")
    let kind = activeAdKind
    releasePresentingAd(for: kind)
    completeShow(with: "failed")
  }
}
