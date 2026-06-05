import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart'; // AdMob
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:google_fonts/google_fonts.dart'; // Added
import 'package:shared_preferences/shared_preferences.dart';
import 'reader_novel.dart';
import 'reader_ebook.dart';
import 'reader_notifications.dart';
import '../home_screens/login_screen.dart'; // For logout navigation
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class ReaderMain extends StatefulWidget {
  const ReaderMain({super.key});

  @override
  State<ReaderMain> createState() => _ReaderMainState();
}

class _ReaderMainState extends State<ReaderMain> {
  BannerAd? _bannerAd; // nullable
  bool _isBannerAdReady = false;
  String _username = "Reader"; // Default

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadUsername();
    _requestTrackingAuthorization();
  }

  Future<void> _requestTrackingAuthorization() async {
    if (!Platform.isIOS) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await Future.delayed(const Duration(milliseconds: 1500));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (e) {
        debugPrint("⚠️ AppTrackingTransparency error: $e");
      }
    });
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _username = "Guest";
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
         setState(() {
           _username = doc.data()?['username'] ?? "Reader";
         });
      }
    } catch (e) {
      debugPrint("Error loading username: $e");
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: Platform.isIOS 
          ? 'ca-app-pub-6924141712831128/7287187011' 
          : 'ca-app-pub-6924141712831128/3318428593', 
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
  
  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut(); // Critical
      await Supabase.instance.client.auth.signOut();
      await GoogleSignIn.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error logging out: $e");
    }
  }

  Future<void> _handleDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          'Are you sure you want to permanently delete your account? All your data, profile, and unlocked books will be permanently removed. This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.red)),
      ),
    );

    try {
      final uid = user.uid;

      // 1. Delete Firestore user document
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 2. Delete user in Firebase Auth
      await user.delete();

      // 3. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account successfully deleted")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (e.code == 'requires-recent-login') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Re-authentication Required'),
              content: const Text(
                'For security reasons, deleting your account requires a recent login. Please log out, log back in, and try deleting your account again.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting account: ${e.message}")),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting account: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Farwa Khalid eBook Novels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF0D2144),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Novels'),
              Tab(text: 'Ebooks'),
              Tab(text: 'Notifications'),
            ],
          ),
        ),
        drawer: Drawer(
          child: Column(
            children: [
               DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF0D2144)),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          _username.isNotEmpty ? _username[0].toUpperCase() : 'G',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D2144)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome, $_username',
                        style: GoogleFonts.poppins(
                          color: Colors.white, 
                          fontSize: 18,
                          fontWeight: FontWeight.w600
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                       Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'Guest Mode',
                        style: GoogleFonts.poppins(
                          color: Colors.white70, 
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (FirebaseAuth.instance.currentUser == null) ...[
                ListTile(
                  leading: const Icon(Icons.login, color: Color(0xFF0D2144)),
                  title: const Text('Sign In / Register'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: _handleLogout,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  onTap: _handleDeleteAccount,
                ),
              ],
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: const TabBarView(
                  children: [
                    ReaderNovel(),
                    ReaderEbook(),
                    ReaderNotifications(),
                  ],
                ),
              ),
              if (_isBannerAdReady && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
