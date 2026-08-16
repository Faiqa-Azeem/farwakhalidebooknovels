import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// iOS-only reader screenshot/recording block via native Swift (no screen_protector).
class IosReaderProtection {
  IosReaderProtection._();

  static const MethodChannel _channel =
      MethodChannel('com.farwa.farwa_khalid/reader_protection');

  static Future<bool> enable() async {
    if (!Platform.isIOS) return false;
    final ok = await _channel.invokeMethod<bool>('enable');
    return ok ?? false;
  }

  static Future<void> disable() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('disable');
  }
}
