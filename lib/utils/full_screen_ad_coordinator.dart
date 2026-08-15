import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_log.dart';
import 'screen_protection_helper.dart';

enum FullScreenAdResult {
  /// Interstitial closed normally, or rewarded closed after earning reward.
  dismissed,

  /// Rewarded ad closed without earning reward.
  dismissedWithoutReward,

  /// Rewarded ad closed and [onUserEarnedReward] ran.
  dismissedWithReward,

  failed,
  skipped,
}

/// Serializes full-screen AdMob presentation across the app.
class FullScreenAdCoordinator {
  FullScreenAdCoordinator._();

  static final FullScreenAdCoordinator instance = FullScreenAdCoordinator._();

  bool _isFullScreenAdShowing = false;

  bool get isFullScreenAdShowing => _isFullScreenAdShowing;

  Future<FullScreenAdResult> showInterstitial(InterstitialAd ad) async {
    if (_isFullScreenAdShowing) {
      AdMobLog.debug('show blocked: full-screen ad lock held');
      return FullScreenAdResult.skipped;
    }

    await ScreenProtectionHelper.ensureOffBeforeAd();

    final completer = Completer<FullScreenAdResult>();
    var finished = false;

    void finish(FullScreenAdResult result) {
      if (finished) return;
      finished = true;
      _isFullScreenAdShowing = false;
      AdMobLog.debug('lock released');
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AdMobLog.debug('full screen presented (interstitial)');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        AdMobLog.debug('dismissed (interstitial)');
        finish(FullScreenAdResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        AdMobLog.debug('failed to show (interstitial): ${error.message}');
        finish(FullScreenAdResult.failed);
      },
    );

    Future<void> present() async {
      if (_isFullScreenAdShowing) {
        finish(FullScreenAdResult.skipped);
        return;
      }
      _isFullScreenAdShowing = true;
      AdMobLog.debug('show requested (interstitial)');
      try {
        ad.show();
      } catch (e) {
        AdMobLog.debug('show threw (interstitial): $e');
        finish(FullScreenAdResult.failed);
      }
    }

    await present();
    return completer.future;
  }

  Future<FullScreenAdResult> showRewarded(
    RewardedAd ad, {
    required Future<void> Function() onUserEarnedReward,
  }) async {
    if (_isFullScreenAdShowing) {
      AdMobLog.debug('show blocked: full-screen ad lock held');
      return FullScreenAdResult.skipped;
    }

    await ScreenProtectionHelper.ensureOffBeforeAd();

    final completer = Completer<FullScreenAdResult>();
    var finished = false;
    var rewardEarned = false;

    void finish(FullScreenAdResult result) {
      if (finished) return;
      finished = true;
      _isFullScreenAdShowing = false;
      AdMobLog.debug('lock released');
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AdMobLog.debug('full screen presented (rewarded)');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        AdMobLog.debug('dismissed (rewarded)');
        finish(
          rewardEarned
              ? FullScreenAdResult.dismissedWithReward
              : FullScreenAdResult.dismissedWithoutReward,
        );
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        AdMobLog.debug('failed to show (rewarded): ${error.message}');
        finish(FullScreenAdResult.failed);
      },
    );

    Future<void> present() async {
      if (_isFullScreenAdShowing) {
        finish(FullScreenAdResult.skipped);
        return;
      }
      _isFullScreenAdShowing = true;
      AdMobLog.debug('show requested (rewarded)');
      try {
        ad.show(
          onUserEarnedReward: (ad, reward) async {
            AdMobLog.debug('reward earned');
            rewardEarned = true;
            await onUserEarnedReward();
          },
        );
      } catch (e) {
        AdMobLog.debug('show threw (rewarded): $e');
        finish(FullScreenAdResult.failed);
      }
    }

    await present();
    return completer.future;
  }

  /// Preload only after navigation has had one clean frame cycle.
  void schedulePreload(VoidCallback preload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFullScreenAdShowing) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isFullScreenAdShowing) return;
        AdMobLog.debug('next ad preload');
        preload();
      });
    });
  }

  /// Run navigation/business logic on the next frame after ad dismiss.
  Future<void> runAfterDismiss(Future<void> Function() action) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AdMobLog.debug('navigation start');
      await action();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
