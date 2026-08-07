import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen protection is enabled only on episode/ebook reader content.
/// Everywhere else (ads, lists, unlock screens) must stay unprotected.
class ScreenProtectionHelper {
  static bool _readerProtectionActive = false;

  static bool get isReaderProtectionActive => _readerProtectionActive;

  /// Turn off reader screenshot protection (safe to call anytime).
  static Future<void> disableForReader() async {
    if (!_readerProtectionActive) return;
    try {
      await ScreenProtector.preventScreenshotOff();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      }
      _readerProtectionActive = false;
    } catch (e) {
      debugPrint('ScreenProtection disable reader error: $e');
    }
  }

  /// Full reset before ads / when leaving reader — clears any stuck iOS layers.
  static Future<void> disableForAdFlow() async {
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
      _readerProtectionActive = false;
    } catch (e) {
      debugPrint('ScreenProtection disable ad-flow error: $e');
    }
  }

  /// iOS sometimes keeps layers active; call once before showing a full-screen ad.
  static Future<void> ensureDisabledBeforeAd() async {
    await disableForAdFlow();
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 80));
      await disableForAdFlow();
    }
  }

  /// Alias used when returning from reader / novel navigation.
  static Future<void> forceDisableForAdFlow() => disableForAdFlow();

  /// Enable screenshot blocking on the episode reader only.
  static Future<void> enableForReader() async {
    try {
      await ScreenProtector.preventScreenshotOn();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      }
      _readerProtectionActive = true;
    } catch (e) {
      debugPrint('ScreenProtection enable error: $e');
    }
  }

  /// Re-apply reader protection after overlays (theme dialog) or app resume.
  static Future<void> reenableForReaderIfNeeded() async {
    if (!_readerProtectionActive) return;
    await enableForReader();
  }
}
