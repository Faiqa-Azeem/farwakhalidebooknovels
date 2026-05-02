import 'dart:io';
import 'package:flutter/services.dart';

class ContentProtectionService {
  static const MethodChannel _channel = MethodChannel('screen_security');
  
  /// Check if device has aggressive OEM screenshot bypass
  static Future<bool> hasOEMScreenshotBypass() async {
    try {
      // Check for known OEM screenshot services
      final String brand = Platform.isAndroid ? 'android' : 'ios';
      
      // Common OEM identifiers that bypass FLAG_SECURE
      final List<String> problematicOEMs = [
        'xiaomi', 'miui', 'oppo', 'coloros', 'vivo', 'funtouch',
        'oneplus', 'oxygenos', 'realme', 'samsung', 'huawei', 'emui'
      ];
      
      // This is a simplified check - in reality you'd need device info
      return true; // Assume OEM bypass for now
    } catch (e) {
      return false;
    }
  }
  
  /// Enable screen security with OEM detection
  static Future<void> enableScreenSecurity() async {
    try {
      await _channel.invokeMethod('enableScreenSecurity');
      
      final hasOEMBypass = await hasOEMScreenshotBypass();
      if (hasOEMBypass) {
        print('⚠️ WARNING: Device may bypass app-level screenshot protection');
        print('📱 Consider additional content protection measures');
      }
    } catch (e) {
      print('Screen security error: $e');
    }
  }
  
  /// Disable screen security
  static Future<void> disableScreenSecurity() async {
    try {
      await _channel.invokeMethod('disableScreenSecurity');
    } catch (e) {
      print('Screen security disable error: $e');
    }
  }
  
  /// Show warning dialog for OEM devices
  static String getOEMWarningMessage() {
    return '''
⚠️ CONTENT PROTECTION NOTICE

Your device uses a custom Android version that may bypass standard screenshot protection.

RECOMMENDATIONS:
• Be cautious when reading sensitive content
• Avoid reading in public or shared spaces  
• Consider using device-level security settings
• Report any unauthorized content sharing

This app implements maximum available protection, but some device manufacturers override standard Android security features.
''';
  }
  
  /// Alternative protection strategies
  static Map<String, String> getAlternativeProtectionStrategies() {
    return {
      'Watermarking': 'Add visible/invisible watermarks to content',
      'Time-limited Access': 'Content expires after reading time',
      'Server-side Control': 'Content fetched in small chunks',
      'User Authentication': 'Biometric verification for sensitive content',
      'Device Binding': 'Content tied to specific device identifiers',
      'Network Monitoring': 'Detect suspicious sharing patterns'
    };
  }
}
