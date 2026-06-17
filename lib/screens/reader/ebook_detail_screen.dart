import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome if needed
import 'package:screen_protector/screen_protector.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart'; // Added
import '../home_screens/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/ebook.dart';
import '../../utils/supabase_service.dart';
import '../../utils/supabase_service.dart';
import '../../utils/purchase_service.dart'; // Added
import 'ebook_reader_screen.dart';
import 'voiceover_player_screen.dart';
class EbookDetailScreen extends StatefulWidget {
  final Ebook ebook;
  const EbookDetailScreen({super.key, required this.ebook});

  @override
  State<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _scenes = [];
  bool _isLoading = true;
  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentSceneIndex = 0;

  // New State for Purchase
  int? _price;
  bool _hasAccess = false;
  bool _checkingAccess = true;

  List<Map<String, dynamic>> _voiceovers = [];
  bool _isLoadingVoices = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _loadEbookScenes();
    _checkAccessAndPrice();
    _loadVoiceovers();
    // Initialize Billing
    PurchaseService().init();
    PurchaseService().onError = (msg, isError) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
         );
      }
    };
    PurchaseService().onSuccess = (msg) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(msg), backgroundColor: Colors.green),
         );
         // Refresh access check
         _checkAccessAndPrice();
      }
    };
  }

  Future<void> _secureScreen() async {
    await ScreenProtector.preventScreenshotOn();
  }

  Future<void> _loadVoiceovers() async {
    setState(() => _isLoadingVoices = true);
    final voiceovers = await SupabaseService.getVoiceoversForItem('ebook', widget.ebook.id);
    if (mounted) {
      setState(() {
        _voiceovers = voiceovers;
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _checkAccessAndPrice() async {
    try {
      final client = Supabase.instance.client;
      
      // FIX: Use Firebase Auth instead of Supabase Auth
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? 'guest';

      print("👤 Checking access for email: $email"); // Debug log

      // 1. Get Price
      try {
        final priceRes = await client
            .from('ebooks')
            .select('price')
            .eq('id', widget.ebook.id)
            .single();
        _price = priceRes['price'] as int?;
      } catch (e) {
        print("Network price fetch failed, using local: $e");
        _price = widget.ebook.price;
      }

      // 2. Check Access
      // If price is 0 or null -> Free
      if (_price == null || _price == 0) {
        if (mounted) setState(() => _hasAccess = true);
      } else {
        // Check payment/access with Device Locking
        // Get Device ID
        String deviceId = 'unknown_device';
        try {
          // You need to add device_info_plus to pubspec if not already there
           final deviceInfo = await DeviceInfoPlugin().androidInfo;
           deviceId = deviceInfo.id; // Unique Android ID
        } catch (e) {
            print("Error getting device info: $e");
        }

        final hasPaid = await SupabaseService.verifyAndLockAccess(
          email: email, 
          ebookId: widget.ebook.id,
          deviceId: deviceId, // Use real device ID
        );
        
        if (mounted) setState(() => _hasAccess = hasPaid);
      }
    } catch (e) {
      debugPrint("Error checking access: $e");
    } finally {
      if (mounted) setState(() => _checkingAccess = false);
    }
  }

  void _showSignInRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('To start reading ebooks and premium content, please sign in or create an account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D2144),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showVoiceoversModal() {
    if (!_hasAccess) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSignInRequiredDialog();
        return;
      }
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Voiceovers", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D2144))),
              const SizedBox(height: 16),
              if (_isLoadingVoices)
                const CircularProgressIndicator()
              else if (_voiceovers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No voiceovers available for this ebook yet.", textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _voiceovers.length,
                    itemBuilder: (context, index) {
                      final voice = _voiceovers[index];
                      return ListTile(
                        leading: const Icon(Icons.play_circle_fill, color: Color(0xFF0D2144)),
                        title: Text(voice['title'] ?? 'Part ${voice['part_number']}'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VoiceoverPlayerScreen(
                                title: voice['title'] ?? 'Part ${voice['part_number']}',
                                audioUrl: voice['audio_url'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReadAction() async {
    if (_hasAccess) {
      // Open Reader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EbookReaderScreen(ebook: widget.ebook),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSignInRequiredDialog();
      return;
    }

    // Show Purchase Dialog
    _showPurchaseDialog();
  }

  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Icon(Icons.lock_open_rounded, size: 50, color: Color(0xFF0D2144)),
              const SizedBox(height: 12),
              const Text(
                "Unlock Full Book",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF0D2144)
                ),
              ),
              const SizedBox(height: 24),
              
              // 1. Pakistan Option (Urdu) - Hidden on iOS to comply with App Store Guidelines
              if (!Platform.isIOS) ...[
                const Text(
                  "پاکستان کے لیے", // For Pakistan
                  style: TextStyle(
                    fontSize: 24, // Larger for Urdu
                    fontFamily: 'JameelNooriNastaleeq', 
                    color: Colors.green,
                    height: 1.2,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                const Text(
                  "اگر آپ پاکستان سے ہیں اور یہ ای بک پڑھنا چاہتے ہیں، تو ہماری رائٹر سے واٹس ایپ پر رابطہ کریں۔ رسائی ملنے کے بعد آپ کو یہاں 'Read Now' کا بٹن نظر آئے گا۔", 
                  style: TextStyle(
                    fontSize: 18, 
                    fontFamily: 'JameelNooriNastaleeq', 
                    color: Colors.black87,
                    height: 1.6
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchWhatsApp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text(
                      "Contact on WhatsApp", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("OR", style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
              ],

              // 2. In-App Purchase Option
              if (!Platform.isIOS) ...[
                const Text(
                  "International / Indian Users",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                "Instant unlock via ${Platform.isIOS ? 'App Store' : 'Play Store'}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                     // Calculate ID: tier_500
                     final String productId = 'tier_${_price ?? 0}';
                     // Set Pending Info
                     final user = FirebaseAuth.instance.currentUser;
                     if (user?.email == null) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Login first!")));
                       return;
                     }
                     PurchaseService.pendingEbookId = widget.ebook.id;
                     PurchaseService.pendingUserEmail = user!.email;
                     
                     // Launch
                     PurchaseService().buyTopUp(productId, widget.ebook.id, user!.email!);
                     Navigator.pop(context); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Platform.isIOS ? Icons.payment : Icons.g_mobiledata, size: 28), 
                  label: Text(
                    "Pay Rs ${_price ?? 0}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ), 
                ),
              ),
              
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
      try {
        final message = Uri.encodeComponent("I want to unlock ${widget.ebook.title}");
        final url = "https://wa.me/923439218819?text=$message";
        const platform = MethodChannel('com.farwa.farwa_khalid/launch');
        await platform.invokeMethod('launchUrl', {'url': url});
      } catch (e) {
         try {
            final message = Uri.encodeComponent("I want to unlock ${widget.ebook.title}");
            final url = Uri.parse("https://wa.me/923439218819?text=$message");
            await launchUrl(url, mode: LaunchMode.externalApplication);
         } catch(e2) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open WhatsApp: $e2")));
             }
         }
      }
      if (mounted) Navigator.pop(context);
  }


  Future<void> _loadEbookScenes() async {
  setState(() => _isLoading = true);

  final scenes = await SupabaseService.getEbookScenes(widget.ebook.id);

  if (mounted) {
    setState(() {
      _scenes = scenes;
      _isLoading = false;
      _currentSceneIndex = 0;
    });
  }
}
 
  /* ---------------------------------------------------- */
  /*  MAIN UI                                             */
  /* ---------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    super.build(context);
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.ebook.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: mainBlue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(mainBlue)))
            : _buildPagedScenesView(),
      ),
    );
  }

  Widget _buildPagedScenesView() {
    const mainBlue = Color(0xFF0D2144);
    if (_scenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No scenes available',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentSceneIndex = idx),
            itemCount: _scenes.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final scene = _scenes[index];
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: _buildSceneCard(scene, index + 1),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentSceneIndex > 0
                          ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut)
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentSceneIndex < _scenes.length - 1
                          ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut)
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _checkingAccess
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _hasAccess
                        ? Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: _showVoiceoversModal,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.headphones),
                                  label: const Text("Voices", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _handleReadAction,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: const Icon(Icons.book),
                                  label: const Text("Read Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _handleReadAction,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14)),
                            icon: const Icon(Icons.lock_open),
                            label: const Text(
                              "Unlock Book",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSceneCard(Map<String, dynamic> scene, int sceneNumber) {
    const mainBlue = Color(0xFF0D2144);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scene['image_url'] != null)
          RepaintBoundary(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: () {
                    final url = scene['image_url'] as String?;
                    if (url == null) {
                      return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                          ),
                        );
                    }

                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(mainBlue),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );

                }(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onLongPress: () {},
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    scene['text'] ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'JameelNooriNastaleeq',
                      fontSize: 22,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }
}
