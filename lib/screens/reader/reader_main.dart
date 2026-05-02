import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // AdMob
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:google_fonts/google_fonts.dart'; // Added
import 'reader_novel.dart';
import 'reader_ebook.dart';
import 'reader_notifications.dart';
import '../home_screens/login_screen.dart'; // For logout navigation

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
  }

  Future<void> _loadUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
           setState(() {
             _username = doc.data()?['username'] ?? "Reader";
           });
        }
      }
    } catch (e) {
      debugPrint("Error loading username: $e");
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-6924141712831128/3318428593', 
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
                          _username.isNotEmpty ? _username[0].toUpperCase() : 'R',
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
                        FirebaseAuth.instance.currentUser?.email ?? '',
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
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _handleLogout,
              ),
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
