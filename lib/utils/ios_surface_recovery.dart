import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Calls native iOS code to force the Flutter view to redraw after AdMob ads.
class IosSurfaceRecovery {
  static const MethodChannel _channel = MethodChannel(
    'com.farwa.farwa_khalid/surface_recovery',
  );

  static Future<void> recoverSurface() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('recoverSurface');
    } catch (e) {
      debugPrint('IosSurfaceRecovery error: $e');
    }
  }
}
