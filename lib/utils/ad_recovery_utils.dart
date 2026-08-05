import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Waits for the Flutter surface to repaint after a full-screen ad closes.
/// Android ad Activities tear down slower than iOS, so a longer delay is used.
Future<void> waitForAdDismissRecovery() async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    var attempts = 0;
    while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        attempts < 40) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  await SchedulerBinding.instance.endOfFrame;

  final delayMs = Platform.isAndroid ? 500 : 300;
  await Future.delayed(Duration(milliseconds: delayMs));

  await SchedulerBinding.instance.endOfFrame;
}

/// Forces a widget rebuild after ad dismiss to prevent a black Flutter surface.
Future<void> recoverFromFullScreenAd(VoidCallback refreshUi) async {
  await waitForAdDismissRecovery();
  refreshUi();
  await SchedulerBinding.instance.endOfFrame;
}
