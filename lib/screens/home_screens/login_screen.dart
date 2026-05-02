import 'package:farwa_khalid_ebook_novels/screens/writer/writer_main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
