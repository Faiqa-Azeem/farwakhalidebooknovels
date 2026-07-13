import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/home_screens/set_username_screen.dart';
import 'screens/home_screens/login_screen.dart';
import 'screens/reader/reader_main.dart';
import 'screens/writer/writer_main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initTrackingAndConfig();
  }

  Future<void> _initTrackingAndConfig() async {
    // 1. Wait a bit for the app UI to render
    await Future.delayed(const Duration(milliseconds: 1000));

    // 2. Request Tracking Authorization on iOS
    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus
            .timeout(const Duration(seconds: 2), onTimeout: () {
          debugPrint("⚠️ AppTrackingTransparency status check timed out.");
          return TrackingStatus.notDetermined;
        });
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization()
              .timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint("⚠️ AppTrackingTransparency request authorization timed out.");
            return TrackingStatus.notDetermined;
          });
        }
      } catch (e) {
        debugPrint("⚠️ AppTrackingTransparency error: $e");
      }
    }

    // 3. Initialize Google Mobile Ads after ATT dialog is resolved
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint("⚠️ Mobile Ads init failed: $e");
    }

    // 4. Continue to login check
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    bool loggedIn = false;
    bool usernameSet = false;
    bool isWriter = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      loggedIn = prefs.getBool('logged_in') ?? false;
      usernameSet = prefs.getBool('username_set') ?? false;
      isWriter = prefs.getBool('is_writer') ?? false;

      debugPrint('🔎 Splash prefs → loggedIn: $loggedIn, '
          'usernameSet: $usernameSet, isWriter: $isWriter');
    } catch (e) {
      debugPrint("⚠️ Error reading login state: $e");
    }

    User? currentUser;
    try {
      if (Firebase.apps.isNotEmpty) {
        currentUser = FirebaseAuth.instance.currentUser;
      }
    } catch (e) {
      debugPrint('⚠️ FirebaseAuth currentUser read failed: $e');
    }
    debugPrint('🔎 Firebase currentUser: ${currentUser?.email ?? "none"}');

    // Show splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // ✅ Extra safety check: if prefs say logged in but Firebase has no session → go to ReaderMain (Guest)
    if (loggedIn && currentUser == null) {
      debugPrint("⚠️ Prefs say logged in but Firebase has no session → go to ReaderMain (Guest)");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReaderMain()),
      );
      return;
    }

    // Normal navigation flow
    if (loggedIn) {
      if (isWriter) {
        debugPrint("✅ Splash → Navigating to WriterMain");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WriterMain()),
        );
      } else {
        if (usernameSet) {
          debugPrint("✅ Splash → Navigating to ReaderMain");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReaderMain()),
          );
        } else {
          debugPrint("✅ Splash → Navigating to ReaderMain (Username not set)");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReaderMain()),
          );
        }
      }
    } else {
      debugPrint("✅ Splash → Navigating to ReaderMain (Guest Mode)");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReaderMain()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2144), // dark blue background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              'assets/images/logo.png',
              height: 180,
            ),
            const SizedBox(height: 20),

            // App Name
            const Text(
              'Farwa Khalid',
              style: TextStyle(
                fontFamily: 'DancingScript',
                fontSize: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            const Text(
              'eBook Novels',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Tagline
            const Text(
              'Read premium novels securely',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Color(0xFFA5ACC6),
              ),
            ),
            const SizedBox(height: 50),

            // Loader
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
