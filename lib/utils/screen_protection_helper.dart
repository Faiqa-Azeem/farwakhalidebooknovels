import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Keeps ads and navigation screens safe from iOS blank-screen issues.
class ScreenProtectionHelper {
  /// Turn off protection before ads, unlock screens, and novel browsing.
  static Future<void> disableForAdFlow() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (e) {
      debugPrint('ScreenProtection disable error: $e');
    }
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
    } catch (e) {
      debugPrint('ScreenProtection enable error: $e');
    }
  }
}
