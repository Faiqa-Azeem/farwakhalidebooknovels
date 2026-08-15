import 'package:flutter/foundation.dart';

/// Debug-only AdMob lifecycle logging.
class AdMobLog {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[ADMOB] $message');
    }
  }
}
