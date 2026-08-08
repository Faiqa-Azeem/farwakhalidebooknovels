import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'ad_recovery_utils.dart';
import 'screen_protection_helper.dart';

/// Presents full-screen ads and runs a strict iOS recovery pipeline afterward.
class AdFlowHelper {
  static Future<void> presentFullScreenAd({
    required BuildContext context,
    required Future<void> Function() showAd,
  }) async {
    await ScreenProtectionHelper.ensureOffBeforeAd();
    await runOnNextFrame(showAd);
  }

  static Future<void> completeAfterDismiss({
    required BuildContext context,
    VoidCallback? preloadNextAd,
    required Future<void> Function() continueFlow,
  }) async {
    await ScreenProtectionHelper.ensureOffBeforeAd();
    await recoverAfterFullScreenAd(context: context);

    preloadNextAd?.call();

    if (context.mounted) {
      await runAfterAdRecovery(context, continueFlow);
    }
  }

  /// Replaces the current screen with a fresh instance (iOS only).
  /// Fixes a stuck black Flutter surface by rebuilding the whole route.
  static Future<void> replaceRouteOnIos<T extends Widget>({
    required BuildContext context,
    required T Function() buildScreen,
  }) async {
    if (!Platform.isIOS || !context.mounted) return;
    await recoverAfterFullScreenAd(context: context);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => buildScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
