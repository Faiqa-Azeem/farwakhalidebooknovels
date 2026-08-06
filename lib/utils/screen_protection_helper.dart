import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Keeps ads and navigation screens safe from iOS blank-screen issues.
class ScreenProtectionHelper {
  static bool _readerProtectionActive = false;

  static bool get isReaderProtectionActive => _readerProtectionActive;

  /// Turn off all protection layers before ads, unlock screens, and novel browsing.
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
      debugPrint('ScreenProtection disable error: $e');
    }
  }

  /// iOS sometimes keeps protection active unless disabled twice.
  static Future<void> forceDisableForAdFlow() async {
    await disableForAdFlow();
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 150));
      await disableForAdFlow();
    }
  }

  /// Call immediately before showing any full-screen ad.
  static Future<void> ensureDisabledBeforeAd() async {
    await forceDisableForAdFlow();
  }

  /// Enable protection only on the episode/ebook reader content screen.
  static Future<void> enableForReader() async {
    try {
      await Future.delayed(
        Duration(milliseconds: Platform.isIOS ? 800 : 300),
      );
      await ScreenProtector.preventScreenshotOn();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      }
      _readerProtectionActive = true;
    } catch (e) {
      debugPrint('ScreenProtection enable error: $e');
    }
  }
}
