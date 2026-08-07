import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Waits until the app is foreground and Flutter has finished frame work.
Future<void> waitForAdDismissRecovery() async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    var attempts = 0;
    while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        attempts < 60) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  await _waitForFrames(Platform.isIOS ? 4 : 2);

  final delayMs = Platform.isIOS ? 900 : 500;
  await Future.delayed(Duration(milliseconds: delayMs));

  await _waitForFrames(Platform.isIOS ? 3 : 2);
}

/// Mimics the repaint that happens when the user switches away and back.
Future<void> recoverAfterFullScreenAd({BuildContext? context}) async {
  await waitForAdDismissRecovery();

  final binding = WidgetsBinding.instance;
  for (var i = 0; i < (Platform.isIOS ? 5 : 2); i++) {
    binding.scheduleForcedFrame();
    await binding.endOfFrame;
  }

  if (context != null && context.mounted) {
    final element = context as Element;
    element.markNeedsBuild();
  }
}

/// Run navigation/UI work only after the surface has recovered.
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

Future<void> _waitForFrames(int count) async {
  for (var i = 0; i < count; i++) {
    await SchedulerBinding.instance.endOfFrame;
  }
}
