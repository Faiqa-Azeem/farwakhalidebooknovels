import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen protection is enabled only on [ChapterReaderScreen] when
/// [enableScreenProtection] is true.
class ScreenProtectionHelper {
  static bool _episodeContentProtected = false;

  static bool get isEpisodeContentProtected => _episodeContentProtected;

  static Future<void> enableEpisodeContentProtection() async {
    try {
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
    _episodeContentProtected = false;
  }

  /// Call once before a full-screen ad if the reader may still own protection.
  static Future<void> ensureOffBeforeAd() async {
    if (!_episodeContentProtected) return;
    await disableAll();
  }

  static Future<void> restoreReaderProtectionIfNeeded(bool enabled) async {
    if (enabled) {
      await enableEpisodeContentProtection();
    }
  }
}
