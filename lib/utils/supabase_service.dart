import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

import '../models/novel.dart';
import '../models/scene.dart';
import '../models/ebook.dart';
import '../models/local_scene.dart';

class SupabaseService {
  /// 🔑 Supabase Project URL + Anon Key
  static const String supabaseUrl = "https://sbwyuykklschxdmxlkcq.supabase.co";
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNid3l1eWtrbHNjaHhkbXhsa2NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0MjY5NDcsImV4cCI6MjA2ODAwMjk0N30.XFTEUjkYXzG0GNNnVnAw6nP1L8Fx628nwBUkSa8fPgs";

  /* ---------------------------------------------------- */
  /*  SAFETY SWITCHES & CACHE CONTROL                     */
  /* ---------------------------------------------------- */
  /// 🚨 HARD KILL SWITCH: Set to false to STOP ALL NETWORK TRAFFIC
  static const bool SUPABASE_ENABLED = true;

  /// 🧠 Session Cache to enforce "One Fetch Per Session"
  static final Set<String> _fetchedThisSession = {};
  static Set<String> get sessionCache => _fetchedThisSession;

  static final SupabaseClient _client =
      SupabaseClient(supabaseUrl, supabaseAnonKey);

  /// 🛡️ Debug Assertion Helper
  static void _assertSafeFetch(String table, {int? limit}) {
    assert(() {
      if (limit == null) {
        // Warning: fetching without limit is dangerous for large tables
        print('⚠️ Warning: Fetching from $table without explicit limit in debug mode.');
        // In strict mode, we might want to fail:
        // assert(false, "🚨 GLOBAL FETCH DETECTED on $table! Use limit() or strict filters.");
      }
      return true;
    }());
  }

  /// 🧹 Clear Session Cache (Call this on Upload/Logout)
  static void clearSessionCache() {
    _fetchedThisSession.clear();
    print("🧹 Session cache cleared.");
  }

  /* ---------------------------------------------------- */
  /*  PAYMENTS                                            */
  /* ---------------------------------------------------- */
  static Future<void> insertEbookPayment({
    required String ebookId,
    required String email,
    required String deviceId,
  }) async {
    if (!SUPABASE_ENABLED) {
       print("🛑 Supabase Disabled: Payment insertion skipped.");
       return;
    }
    try {
      await _client.from('ebook_payments').insert({
        'ebook_id': ebookId,
        'email': email,
        'device_id': deviceId,
        'access_granted': false,
      });
    } catch (e) {
      throw Exception('Error inserting payment: $e');
    }
  }

  static Future<String> uploadPaymentProof(File file, String email) async {
    if (!SUPABASE_ENABLED) {
      throw Exception("Supabase is disabled. Cannot upload payment proof.");
    }
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'payments/$email/$fileName';

      final storageResponse =
          await _client.storage.from('payment_proofs').upload(filePath, file);

      if (storageResponse.isEmpty) {
        throw Exception('Failed to upload payment proof.');
      }

      return _client.storage.from('payment_proofs').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading payment proof: $e');
    }
  }

  static Future<bool> getUserPaymentStatus(
      String ebookId, String email) async {
    // This is the old method, keeping for backward compatibility if needed, 
    // but verifyAndLockAccess is the new secure one.
    if (!SUPABASE_ENABLED) return false;
    try {
      final response = await _client
          .from('ebook_payments')
          .select('access_granted')
          .eq('ebook_id', ebookId)
          .eq('email', email)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (response == null) return false;
      return response['access_granted'] == true;
    } catch (e) {
      throw Exception('Error fetching user payment status: $e');
    }
  }

  /* ---------------------------------------------------- */
  /*  ADMIN ACCESS CONTROL & DEVICE LOCKING               */
  /* ---------------------------------------------------- */
  
  /// 🔓 Grant Access (Admin Side or Google Play Billing)
  static Future<void> grantAccess({
    required String email,
    required String ebookId,
  }) async {
    if (!SUPABASE_ENABLED) throw Exception("Supabase is disabled");
    
    try {
      // Check if already exists to avoid error
      final existing = await _client
          .from('ebook_access')
          .select()
          .eq('user_email', email)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('ebook_access').insert({
          'user_email': email,
          'ebook_id': ebookId,
          'device_id': null, // Starts unlocked
          'created_at': DateTime.now().toIso8601String(),
        });
        print("✅ Access inserted in Supabase");
      } else {
        print("User already has access to this eBook! Skipping insert.");
      }

      // 🛠️ CRITICAL FIX: Ensure the user immediately gets offline access cached!
      // This way if they go offline before EbookDetailScreen queries it, they don't get locked out.
      try {
        final box = await Hive.openBox('unlocked_ebooks');
        await box.put('${email}_$ebookId', true);
        print("✅ Access cached offline immediately!");
      } catch (cacheError) {
        print("⚠️ Failed to write to Hive offline cache: $cacheError");
      }
      
    } catch (e) {
      throw Exception('Error granting access: $e');
    }
  }

  /// 🔒 Verify & Lock Access (User Side)
  /// Returns:
  /// - true: Access Allowed
  /// - false: Access Denied (No record OR Device Mismatch)
  static Future<bool> verifyAndLockAccess({
    required String email,
    required String ebookId,
    required String deviceId,
  }) async {
    if (!SUPABASE_ENABLED) return false;

    try {
      // 1. Check if access record exists
      final response = await _client
          .from('ebook_access')
          .select('id, device_id')
          .eq('user_email', email)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      // No record found -> Access Denied
      if (response == null) {
        print("❌ Access Denied: No record found for $email on ebook $ebookId");
        try {
           final box = await Hive.openBox('unlocked_ebooks');
           await box.delete('${email}_$ebookId');
        } catch (_) {}
        return false;
      }

      final String? textDeviceId = response['device_id'] as String?;
      final String recordId = response['id'] as String;

      // 2. Lock if New (First time reading)
      if (textDeviceId == null || textDeviceId.isEmpty) { // Handle empty string too
        print("🔓 First time access! Locking to device: $deviceId");
        
        // Debug Update
        print("Attempting to update ID: $recordId with device_id: $deviceId");
        
        await _client
            .from('ebook_access')
            .update({'device_id': deviceId})
            .eq('id', recordId);
            
        print("✅ DB Update command sent.");
        try {
           final box = await Hive.openBox('unlocked_ebooks');
           await box.put('${email}_$ebookId', true);
        } catch (_) {}
        return true;
      }

      // 3. Verify Device Match
      if (textDeviceId == deviceId) {
        print("✅ Device Match! Access Granted.");
        try {
           final box = await Hive.openBox('unlocked_ebooks');
           await box.put('${email}_$ebookId', true);
        } catch (_) {}
        return true;
      } else {
        print("⛔ DEVICE MISMATCH! Locked to: $textDeviceId, Requesting: $deviceId");
        // Optional: Log this suspicious attempt
        return false;
      }

    } catch (e) {
      print("⚠️ Error verifying access online, checking cache: $e");
      try {
           final box = await Hive.openBox('unlocked_ebooks');
           return box.get('${email}_$ebookId', defaultValue: false);
      } catch (_) {
           return false; 
      }
    }
  }

  /// 📋 Get Access List (Admin Side)
  static Future<List<Map<String, dynamic>>> getAccessList(String ebookId) async {
    if (!SUPABASE_ENABLED) return [];
    try {
      final response = await _client
          .from('ebook_access')
          .select('id, user_email, device_id, created_at')
          .eq('ebook_id', ebookId)
          .order('created_at', ascending: false);
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Error fetching access list: $e');
    }
  }

  /// 🚫 Revoke Access (Admin Side)
  static Future<void> revokeAccess(String accessId) async {
    if (!SUPABASE_ENABLED) return;
    try {
      await _client
          .from('ebook_access')
          .delete()
          .eq('id', accessId);
    } catch (e) {
      throw Exception('Error revoking access: $e');
    }
  }

  /* ---------------------------------------------------- */
  /*  NOVELS                                              */
  /* ---------------------------------------------------- */
  static Future<List<Novel>> getAllNovels({int page = 1, int limit = 20}) async {
    final cacheKey = 'all_novels_page_$page';
    
    // 1. Try to load from Hive Cache first (FASTEST)
    try {
      final box = await Hive.openBox('novels_cache');
      if (box.isNotEmpty) {
        final cachedData = box.get(cacheKey);
        if (cachedData != null) {
          print("📦 Loaded novels (Page $page) from Hive Cache");
          final novels = (cachedData as List)
              .map((json) => Novel.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          
          if (!SUPABASE_ENABLED || _fetchedThisSession.contains(cacheKey)) {
            return novels;
          }
        }
      }
    } catch (e) {
      print("⚠️ Hive Cache Error: $e");
    }

    // 2. Kill Switch Check
    if (!SUPABASE_ENABLED) {
      print("🛑 Supabase Disabled: Returning empty/cached data only.");
      return []; 
    }

    // 3. Network Fetch (If not in session cache)
    if (_fetchedThisSession.contains(cacheKey)) {
      print("⏩ Skipping fetch: Already fetched this session (Page $page).");
      return [];
    }

    try {
      _assertSafeFetch('novels', limit: limit);
      print("🌍 Fetching novels (Page $page) from Supabase...");
      
      final int start = (page - 1) * limit;
      final int end = start + limit - 1;

      final response = await _client
          .from('novels')
          .select('id, title, cover_url, author_id, created_at, updated_at, status') // Explicit columns
          .order('created_at', ascending: false)
          .range(start, end);

      final novels = (response as List)
          .map((json) => Novel.fromJson(json as Map<String, dynamic>))
          .toList();

      // 4. Save to Cache
      final box = await Hive.openBox('novels_cache');
      await box.put(cacheKey, response);
      
      // 5. Mark Session
      _fetchedThisSession.add(cacheKey);
      
      return novels;
    } catch (e) {
      print('❌ Error fetching novels: $e');
      if (e is PostgrestException) {
        print('📌 Postgrest details: ${e.message} code: ${e.code} details: ${e.details}');
      }
      return [];
    }
  }

  static Future<List<Novel>> searchNovels(String query) async {
    if (!SUPABASE_ENABLED) return [];
    try {
      final response = await _client
          .from('novels')
          .select()
          .ilike('title', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Novel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching novels: $e');
      return [];
    }
  }

  static Future<List<Scene>> getNovelScenes(String novelId) async {
    final cacheKey = 'scenes_$novelId';

    // 1. Hive Cache Check
    try {
      final box = await Hive.openBox('scenes_cache');
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        print("📦 Loaded scenes for $novelId from Hive");
        final scenes = (cachedData as List)
          .map((json) => Scene.fromJson(Map<String, dynamic>.from(json)))
          .toList();
        
        if (!SUPABASE_ENABLED || _fetchedThisSession.contains(cacheKey)) {
          return scenes;
        }
      }
    } catch (e) {
      print("⚠️ Hive Cache Error: $e");
    }

    // 2. Kill Switch
    if (!SUPABASE_ENABLED) {
       print("🛑 Supabase Disabled: Scenes not fetched.");
       return [];
    }

    // 3. Network Fetch
    try {
      print("🌍 Fetching scenes for $novelId from Supabase...");
      final response = await _client
          .from('scenes')
          .select()
          .eq('novel_id', novelId) 
          .order('ord', ascending: true);

      final scenes = (response as List)
          .map((json) => Scene.fromJson(json as Map<String, dynamic>))
          .toList();

      // 4. Save Cache
      final box = await Hive.openBox('scenes_cache');
      await box.put(cacheKey, response);
      
      _fetchedThisSession.add(cacheKey);

      return scenes;
    } catch (e) {
      print('❌ Error fetching scenes: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNovelChapters(
      String novelId) async {
    final cacheKey = 'chapters_$novelId';

    // 1. Cache Check
    try {
      final box = await Hive.openBox('chapters_cache');
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        print("📦 Loaded chapters for $novelId from Hive");
        if (!SUPABASE_ENABLED || _fetchedThisSession.contains(cacheKey)) {
          return (cachedData as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {}

    if (!SUPABASE_ENABLED) return [];

    try {
      print("🌍 Fetching chapters for $novelId...");
      final response = await _client
          .from('chapters')
          .select()
          .eq('novel_id', novelId)
          .order('ord', ascending: true);

      // Save Cache
      final box = await Hive.openBox('chapters_cache');
      await box.put(cacheKey, response);
      _fetchedThisSession.add(cacheKey);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error fetching chapters: $e');
      return [];
    }
  }

  /* ---------------------------------------------------- */
  /*  EBOOKS + OFFLINE CACHE                              */
  /* ---------------------------------------------------- */
  static Future<List<Ebook>> getAllEbooks() async {
    const cacheKey = 'all_ebooks';

    // 1. Hive Cache
    try {
      final box = await Hive.openBox('ebooksBox');
      if (box.isNotEmpty) {
        final cachedData = box.get('ebooks');
        if (cachedData != null) {
          final ebooks = (cachedData as List)
              .map((json) => Ebook.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          
          if (!SUPABASE_ENABLED || _fetchedThisSession.contains(cacheKey)) {
            return ebooks;
          }
        }
      }
    } catch (_) {}

    if (!SUPABASE_ENABLED) {
      print("🛑 Supabase Disabled: Ebooks not fetched.");
      return [];
    }

    // 2. Network Fetch
    try {
      _assertSafeFetch('ebooks');
      final response = await _client.from('ebooks').select();

      final ebooks = (response as List)
          .map((json) => Ebook.fromJson(json as Map<String, dynamic>))
          .toList();

      Box box;
      try {
        box = Hive.box('ebooksBox');
      } catch (_) {
        box = await Hive.openBox('ebooksBox');
      }

      await box.put('ebooks', response);
      _fetchedThisSession.add(cacheKey);

      print("✅ Ebooks fetched online & cached in Hive");
      return ebooks;
    } catch (e) {
      print("⚠️ Online fetch failed, loading from Hive instead: $e");

      Box box;
      try {
        box = Hive.box('ebooksBox');
      } catch (_) {
        box = await Hive.openBox('ebooksBox');
      }

      final cached = box.get('ebooks', defaultValue: []);
      return (cached as List)
          .map((json) => Ebook.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
  }

  static Future<List<Ebook>> searchEbooks(String query) async {
    if (!SUPABASE_ENABLED) return []; // Or implement local search logic here
    try {
      final response =
          await _client.from('ebooks').select().ilike('title', '%$query%');

      final ebooks = (response as List)
          .map((json) => Ebook.fromJson(json as Map<String, dynamic>))
          .toList();

      Box box;
      try {
        box = Hive.box('ebooksBox');
      } catch (_) {
        box = await Hive.openBox('ebooksBox');
      }

      await box.put('ebooks', response);
      return ebooks;
    } catch (e) {
      print("⚠️ Search failed online, loading cached Hive ebooks: $e");

      Box box;
      try {
        box = Hive.box('ebooksBox');
      } catch (_) {
        box = await Hive.openBox('ebooksBox');
      }

      final cached = box.get('ebooks', defaultValue: []);
      return (cached as List)
          .map((json) => Ebook.fromJson(Map<String, dynamic>.from(json)))
          .where((ebook) =>
              ebook.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  /* ---------------------------------------------------- */
  /*  SCENES WITH OFFLINE CACHE                           */
  /* ---------------------------------------------------- */
  static Future<List<Map<String, dynamic>>> getEbookScenes(
      String ebookId) async {
    try {
      final response = await _client
          .from('ebook_scenes')
          .select()
          .eq('ebook_id', ebookId)
          .order('ord', ascending: true);

      final scenes = (response as List).cast<Map<String, dynamic>>();

      Box<LocalScene> box;
      try {
        box = Hive.box<LocalScene>('offline_scenes');
      } catch (_) {
        box = await Hive.openBox<LocalScene>('offline_scenes');
      }

      final keysToRemove = box.keys
          .where((k) => k.toString().startsWith('${ebookId}_'))
          .toList();
      await box.deleteAll(keysToRemove);

      for (var json in scenes) {
        await box.put(
          '${ebookId}_${json['ord']}',
          LocalScene(
            ebookId: ebookId,
            ord: json['ord'] ?? 0,
            text: json['text'] ?? '',
            imageUrl: json['image_url'],
          ),
        );
      }

      print("✅ Scenes fetched online & cached for ebook $ebookId");
      return scenes;
    } catch (e) {
      print("⚠️ Online fetch failed, loading cached scenes: $e");

      Box<LocalScene> box;
      try {
        box = Hive.box<LocalScene>('offline_scenes');
      } catch (_) {
        box = await Hive.openBox<LocalScene>('offline_scenes');
      }

      final cachedScenes = box.values
          .where((s) => s.ebookId == ebookId)
          .map((s) => {
                'ebook_id': s.ebookId,
                'ord': s.ord,
                'text': s.text,
                'image_url': s.imageUrl,
              })
          .toList()
        ..sort((a, b) => (a['ord'] as int).compareTo(b['ord'] as int));

      return cachedScenes;
    }
  }

  /* ---------------------------------------------------- */
  /*  CONTENT / NOTIFICATIONS                             */
  /* ---------------------------------------------------- */
  static Future<String?> getEbookContent(String ebookId) async {
    try {
      final response = await _client
          .from('ebook_content')
          .select('content')
          .eq('ebook_id', ebookId)
          .maybeSingle();

      final content = response?['content'] as String?;

      if (content != null) {
        Box<String> box;
        try {
          box = Hive.box<String>('ebook_content_box');
        } catch (_) {
          box = await Hive.openBox<String>('ebook_content_box');
        }

        await box.put(ebookId, content);
        print("✅ Ebook content cached for $ebookId");
      }

      return content;
    } catch (e) {
      print("⚠️ Online fetch failed, loading cached ebook content: $e");

      Box<String> box;
      try {
        box = Hive.box<String>('ebook_content_box');
      } catch (_) {
        box = await Hive.openBox<String>('ebook_content_box');
      }

      return box.get(ebookId);
    }
  }

  static Future<List<Map<String, dynamic>>> getAllNotifications() async {
    try {
      final response = await _client
          .from('post_notifications')
          .select('*')
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  static Future<dynamic> getEbookPrice(String ebookId) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('price')
          .eq('id', ebookId)
          .single();

      return response['price'];
    } catch (e) {
      throw Exception('Error fetching ebook price: $e');
    }
  }

  /* ---------------------------------------------------- */
  /*  VOICEOVERS                                          */
  /* ---------------------------------------------------- */
  static Future<String> uploadVoiceoverAudio(File file, String itemType, String itemId) async {
    if (!SUPABASE_ENABLED) throw Exception("Supabase is disabled.");
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$itemType/$itemId/$fileName';

      final storageResponse =
          await _client.storage.from('voiceovers').upload(filePath, file);

      if (storageResponse.isEmpty) {
        throw Exception('Failed to upload audio.');
      }

      return _client.storage.from('voiceovers').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading voiceover: $e');
    }
  }

  static Future<void> addVoiceoverRecord({
    required String itemType,
    required String itemId,
    required int partNumber,
    required String title,
    required String audioUrl,
  }) async {
    if (!SUPABASE_ENABLED) return;
    try {
      await _client.from('voiceovers').insert({
        'item_type': itemType,
        'item_id': itemId,
        'part_number': partNumber,
        'title': title,
        'audio_url': audioUrl,
      });
    } catch (e) {
      throw Exception('Error inserting voiceover record: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getVoiceoversForItem(String itemType, String itemId) async {
    if (!SUPABASE_ENABLED) return [];
    try {
      final response = await _client
          .from('voiceovers')
          .select()
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .order('part_number', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching voiceovers: $e');
      return [];
    }
  }

  static Future<void> deleteVoiceover(String id) async {
    if (!SUPABASE_ENABLED) return;
    try {
      await _client.from('voiceovers').delete().eq('id', id);
    } catch (e) {
      throw Exception('Error deleting voiceover: $e');
    }
  }

  static Future<void> resequenceVoiceovers(String itemType, String itemId) async {
    if (!SUPABASE_ENABLED) return;
    try {
      final parts = await getVoiceoversForItem(itemType, itemId);
      for (int i = 0; i < parts.length; i++) {
        final expectedPartNumber = i + 1;
        final part = parts[i];
        if (part['part_number'] != expectedPartNumber) {
          await _client.from('voiceovers').update({
            'part_number': expectedPartNumber,
            'title': 'Part $expectedPartNumber',
          }).eq('id', part['id']);
        }
      }
    } catch (e) {
      print('Error resequencing voiceovers: $e');
    }
  }
}
