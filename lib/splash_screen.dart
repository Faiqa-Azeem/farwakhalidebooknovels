import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('🔎 Firebase currentUser: ${currentUser?.email ?? "none"}');

    // Show splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // ✅ Extra safety check: if prefs say logged in but Firebase has no session → force Login
    if (loggedIn && currentUser == null) {
      debugPrint("⚠️ Prefs say logged in but Firebase has no session → go to Login");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
          debugPrint("✅ Splash → Navigating to SetUsernameScreen");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SetUsernameScreen()),
          );
        }
      }
    } else {
      debugPrint("✅ Splash → Navigating to LoginScreen");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
