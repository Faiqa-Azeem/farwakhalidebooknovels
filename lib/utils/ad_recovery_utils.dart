import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'ios_surface_recovery.dart';

/// Waits until the app is foreground and Flutter has finished frame work.
Future<void> waitForAdDismissRecovery() async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    var attempts = 0;
    while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        attempts < 80) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  await _waitForFrames(Platform.isIOS ? 3 : 2);

  final delayMs = Platform.isIOS ? 700 : 400;
  await Future.delayed(Duration(milliseconds: delayMs));

  await _waitForFrames(Platform.isIOS ? 2 : 1);
}

/// Full recovery pipeline — mimics switching away and back to the app.
Future<void> recoverAfterFullScreenAd({BuildContext? context}) async {
  await waitForAdDismissRecovery();
  await IosSurfaceRecovery.recoverSurface();

  final binding = WidgetsBinding.instance;
  for (var i = 0; i < (Platform.isIOS ? 4 : 2); i++) {
    binding.scheduleForcedFrame();
    await binding.endOfFrame;
  }

  if (context != null && context.mounted) {
    (context as Element).markNeedsBuild();
  }
}

Future<void> runAfterAdRecovery(
  BuildContext context,
  Future<void> Function() action,
) async {
  if (!context.mounted) return;

  final completer = Completer<void>();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (context.mounted) {
        await action();
      }
      if (!completer.isCompleted) completer.complete();
    });
  });

  return completer.future;
}

Future<void> runOnNextFrame(Future<void> Function() action) async {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await action();
    if (!completer.isCompleted) completer.complete();
  });
  return completer.future;
}

Future<void> _waitForFrames(int count) async {
  for (var i = 0; i < count; i++) {
    await SchedulerBinding.instance.endOfFrame;
  }
}
