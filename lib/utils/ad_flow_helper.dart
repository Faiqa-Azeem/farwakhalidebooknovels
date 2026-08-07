import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'ad_recovery_utils.dart';
import 'ios_ad_host_screen.dart';
import 'screen_protection_helper.dart';

/// Centralizes iOS-safe ad presentation and post-dismiss recovery.
class AdFlowHelper {
  /// On iOS, pushes a host route before [presentAd] so the native ad does not
  /// corrupt the underlying Flutter surface on the second show.
  static Future<void> presentWithIosHost({
    required BuildContext context,
    required Future<void> Function(BuildContext presentationContext) presentAd,
  }) async {
    if (!Platform.isIOS) {
      await presentAd(context);
      return;
    }

    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => IosAdHostScreen(
          onHostReady: presentAd,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }

  /// Call from onAdDismissed / onAdFailed after disposing the ad instance.
  static Future<void> completeAfterDismiss({
    required BuildContext rootContext,
    BuildContext? iosHostContext,
    VoidCallback? preloadNextAd,
    required Future<void> Function() continueFlow,
  }) async {
    await ScreenProtectionHelper.ensureOffBeforeAd();

    if (Platform.isIOS &&
        iosHostContext != null &&
        iosHostContext.mounted &&
        Navigator.of(iosHostContext).canPop()) {
      Navigator.of(iosHostContext).pop();
      await waitForAdDismissRecovery();
    }

    if (rootContext.mounted) {
      await recoverAfterFullScreenAd(context: rootContext);
    } else {
      await waitForAdDismissRecovery();
    }

    preloadNextAd?.call();

    if (rootContext.mounted) {
      await runAfterAdRecovery(rootContext, continueFlow);
    }
  }
}
