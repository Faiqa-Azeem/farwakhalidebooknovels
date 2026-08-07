import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen protection is allowed on ONE screen only:
/// [ChapterReaderScreen] after the user taps Read Now on [EpisodeUnlockScreen].
class ScreenProtectionHelper {
  static bool _episodeContentProtected = false;

  static bool get isEpisodeContentProtected => _episodeContentProtected;

  /// Enable protection — call only from the episode content reader.
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

  /// Disable all protection — every other screen and when leaving the reader.
  static Future<void> disableAll() async {
    await _turnOffAllLayers();
    _episodeContentProtected = false;
  }

  /// Must be off before any full-screen ad (prevents iOS blank/overlap).
  static Future<void> ensureOffBeforeAd() async {
    await disableAll();
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 80));
      await disableAll();
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
