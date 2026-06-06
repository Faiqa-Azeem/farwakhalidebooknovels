import 'package:farwa_khalid_ebook_novels/screens/writer/writer_main.dart';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'set_username_screen.dart';
import '../reader/reader_main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  // 🔹 Check if already logged in
  Future<void> _checkExistingLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint("🔍 Existing login detected → ${user.email}");

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final role = (doc.data()?['role'] ?? 'reader').toString();
          debugPrint("✅ Role found in Firestore: $role");

          await _saveLoginState(user.email ?? '', true, true, role == 'writer');

          if (!mounted) return;
          if (role == 'writer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WriterMain()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ReaderMain()),
            );
          }
        } else {
          // No profile set yet → go to SetUsername
          debugPrint("⚠️ No user document found, go to SetUsernameScreen");
          await _saveLoginState(user.email ?? '', true, false, false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SetUsernameScreen()),
          );
        }
      } catch (e) {
        debugPrint("❌ Firestore fetch error (checkExistingLogin): $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error fetching profile data")),
        );
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  // 🔹 Save login info locally
  Future<void> _saveLoginState(
      String email, bool loggedIn, bool usernameSet, bool isWriter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged_in', loggedIn);
    await prefs.setBool('username_set', usernameSet);
    await prefs.setBool('is_writer', isWriter);
    await prefs.setString('user_email', email);
  }

  // 🔹 After login success
  Future<void> _postLoginCheck(User user) async {
    debugPrint("🔍 Login completed → ${user.email}");

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        // User already has a profile → check role
        final role = (doc.data()?['role'] ?? 'reader').toString();
        debugPrint("✅ Existing profile found → role=$role");
        await _saveLoginState(user.email ?? '', true, true, role == 'writer');

        if (!mounted) return;
        if (role == 'writer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WriterMain()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReaderMain()),
          );
        }
      } else {
        // No profile yet → go to SetUsername screen
        debugPrint("⚠️ Username not set → ${user.email}");
        await _saveLoginState(user.email ?? '', true, false, false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SetUsernameScreen()),
        );
      }
    } catch (e) {
      debugPrint("❌ Firestore fetch error (postLoginCheck): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching profile data")),
      );
      await FirebaseAuth.instance.signOut();
    }
  }

  // 🔹 Google Login
  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isLoading = true);
      final googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        // accessToken is deprecated/removed in google_sign_in 7.2.x
        // We rely only on idToken for Firebase auth now.
        idToken: googleAuth.idToken,
      );
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _postLoginCheck(userCredential.user!);
    } catch (e) {
      debugPrint("❌ Google Sign-in error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google login failed")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleAppleLogin() async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      setState(() => _isLoading = true);

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        throw Exception("Apple Sign In failed: identityToken is null");
      }

      final credential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception("Firebase Sign In returned a null user");
      }

      await _postLoginCheck(userCredential.user!);
    } catch (e) {
      debugPrint("❌ Apple Sign-in error: $e");
      String errorMessage = e.toString();
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? e.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Apple login failed: $errorMessage"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAppleButton = !kIsWeb && Platform.isIOS;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D2144)),
                onPressed: () => Navigator.maybePop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Hero(
                  tag: 'appLogo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Login to your account",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D2144),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    icon: Image.asset(
                      'assets/images/google_icon.png',
                      height: 24,
                    ),
                    label: Text(
                      "Login with Google",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF0D2144),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF0D2144)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (showAppleButton) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleAppleLogin,
                      icon: const Icon(Icons.apple, color: Color(0xFF0D2144)),
                      label: Text(
                        "Sign in with Apple",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF0D2144),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF0D2144)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('is_guest', true);
                          await prefs.setBool('logged_in', false);
                          await prefs.setBool('username_set', false);
                          await prefs.setBool('is_writer', false);

                          if (!mounted) return;
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ReaderMain()),
                            );
                          }
                        },
                  child: Text(
                    "Browse as Guest",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFF0D2144),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(color: Color(0xFF0D2144)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
