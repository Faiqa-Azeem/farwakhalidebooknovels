import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ Google Mobile Ads
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Hive for offline ebooks
import 'models/ebook.dart'; // ✅ Import Ebook + LocalEbook model
import 'models/local_scene.dart'; // ✅ Offline scenes
import 'utils/screen_security_service.dart';
import 'utils/purchase_service.dart'; // ✅ Global PurchaseService
import 'package:google_sign_in/google_sign_in.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://sbwyuykklschxdmxlkcq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNid3l1eWtrbHNjaHhkbXhsa2NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MjY5NDcsImV4cCI6MjA2ODAwMjk0N30.XFTEUjkYXzG0GNNnVnAw6nP1L8Fx628nwBUkSa8fPgs',
  );

  // ✅ Initialize Google Sign-In
  await GoogleSignIn.instance.initialize(
    serverClientId: '722169672929-hp6utah6eu62plbhl4autqpqgi5ir87o.apps.googleusercontent.com',
  );

  // ✅ Initialize Google Mobile Ads
  await MobileAds.instance.initialize();

  // ✅ Initialize Hive (for offline ebooks + scenes + content)
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(LocalEbookAdapter());
  Hive.registerAdapter(LocalSceneAdapter());

  // Open boxes
  await Hive.openBox<LocalEbook>('offline_ebooks');
  await Hive.openBox<LocalScene>('offline_scenes');
  await Hive.openBox<String>('ebook_content_box'); // 🔧 new content cache

  // ✅ Enable screen security (per-screen, not globally here)

  // ✅ Initialize Billing globally
  PurchaseService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farwa Khalid eBook Novels',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
      ),
      // 👇 Start with SplashScreen
      home: const SplashScreen(),
    );
  }
}
