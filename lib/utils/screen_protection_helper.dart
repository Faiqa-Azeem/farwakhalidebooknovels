import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen protection is allowed on ONE screen only:
/// [ChapterReaderScreen] after the user taps Read Now on [EpisodeUnlockScreen].
class ScreenProtectionHelper {
  static bool _episodeContentProtected = false;

  static bool get isEpisodeContentProtected => _episodeContentProtected;

  static Future<void> enableEpisodeContentProtection() async {
    try {
      await _turnOffAllLayers();
      await ScreenProtector.preventScreenshotOn();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      }
      _episodeContentProtected = true;
    } catch (e) {
      debugPrint('enableEpisodeContentProtection error: $e');
    }
  }

  static Future<void> disableAll() async {
    await _turnOffAllLayers();
    _episodeContentProtected = false;
  }

  /// Before ads: light disable unless the episode reader was active.
  static Future<void> ensureOffBeforeAd() async {
    if (_episodeContentProtected) {
      await disableAll();
      return;
    }

    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('ensureOffBeforeAd error: $e');
    }
  }

  static Future<void> _turnOffAllLayers() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      if (Platform.isIOS) {
        try {
          await ScreenProtector.protectDataLeakageWithBlurOff();
        } catch (_) {}
        try {
          await ScreenProtector.protectDataLeakageWithImageOff();
        } catch (_) {}
      } else {
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (e) {
      debugPrint('disableAll error: $e');
    }
  }
}
