import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

import 'ios_reader_protection.dart';

/// Screen protection is enabled only on [ChapterReaderScreen] when
/// [enableScreenProtection] is true.
///
/// iOS uses a custom native reader protection channel (no screen_protector plugin)
/// to avoid blank Flutter surfaces after full-screen ads.
/// Android uses screen_protector as before.
class ScreenProtectionHelper {
  static bool _episodeContentProtected = false;

  static bool get isEpisodeContentProtected => _episodeContentProtected;

  static Future<void> enableEpisodeContentProtection() async {
    try {
      if (Platform.isIOS) {
        final enabled = await IosReaderProtection.enable();
        _episodeContentProtected = enabled;
        return;
      }
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
      _episodeContentProtected = true;
    } catch (e) {
      debugPrint('enableEpisodeContentProtection error: $e');
    }
  }

  static Future<void> disableAll() async {
    try {
      if (Platform.isIOS) {
        await IosReaderProtection.disable();
        _episodeContentProtected = false;
        return;
      }
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
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
    if (Platform.isIOS) {
      // Custom iOS protection is not tied to UIApplication lifecycle hooks.
      return;
    }
    if (enabled) {
      await enableEpisodeContentProtection();
    }
  }
}
