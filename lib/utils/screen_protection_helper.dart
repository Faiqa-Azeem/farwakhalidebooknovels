import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen protection is enabled only on [ChapterReaderScreen] when
/// [enableScreenProtection] is true.
///
/// iOS: intentionally disabled for production testing. No native
/// screen_protector MethodChannel calls are made on iOS.
class ScreenProtectionHelper {
  static bool _episodeContentProtected = false;

  static bool get isEpisodeContentProtected => _episodeContentProtected;

  static Future<void> enableEpisodeContentProtection() async {
    if (Platform.isIOS) {
      _episodeContentProtected = false;
      return;
    }
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
      _episodeContentProtected = true;
    } catch (e) {
      debugPrint('enableEpisodeContentProtection error: $e');
    }
  }

  static Future<void> disableAll() async {
    if (Platform.isIOS) {
      _episodeContentProtected = false;
      return;
    }
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
    } catch (e) {
      debugPrint('disableAll error: $e');
    }
    _episodeContentProtected = false;
  }

  /// Call once before a full-screen ad if the reader may still own protection.
  static Future<void> ensureOffBeforeAd() async {
    if (Platform.isIOS) return;
    if (!_episodeContentProtected) return;
    await disableAll();
  }

  static Future<void> restoreReaderProtectionIfNeeded(bool enabled) async {
    if (Platform.isIOS) return;
    if (enabled) {
      await enableEpisodeContentProtection();
    }
  }
}
