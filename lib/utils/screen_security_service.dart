import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'content_protection_service.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('screen_security');
  static bool _isSecured = false;

  /// Enable screen security to prevent screenshots and screen recording
  static Future<void> enableScreenSecurity() async {
    if (_isSecured) return;
    
    try {
      await _channel.invokeMethod('enableScreenSecurity');
      _isSecured = true;
      // Removed print statement to reduce console noise
    } catch (e) {
      // Silently fail - screen security is optional and plugin may not be implemented
      _isSecured = false;
    }
  }

  /// Disable screen security
  static Future<void> disableScreenSecurity() async {
    try {
      await _channel.invokeMethod('disableScreenSecurity');
      _isSecured = false;
      // Removed print statement to reduce console noise
    } catch (e) {
      // Silently fail - screen security is optional and plugin may not be implemented
      _isSecured = false;
    }
  }

  /// Check if screen security is currently enabled
  static bool get isSecured => _isSecured;

  /// Show OEM warning dialog
  static void showOEMWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Content Protection Notice'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              ContentProtectionService.getOEMWarningMessage(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }

  /// Enable security for sensitive screens (reader screens)
  static Future<void> enableForSensitiveContent() async {
    await enableScreenSecurity();
  }

  /// Disable security when leaving sensitive screens
  static Future<void> disableForNormalContent() async {
    // Keep security enabled throughout the app for maximum protection
    // await disableScreenSecurity();
  }
}
