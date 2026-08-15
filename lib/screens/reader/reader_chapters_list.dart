import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/novel.dart';
import '../../utils/admob_log.dart';
import '../../utils/full_screen_ad_coordinator.dart';
import '../../utils/supabase_service.dart';
import 'episode_unlock_screen.dart';
import 'voiceover_player_screen.dart';

class ReaderChaptersList extends StatefulWidget {
  final Novel novel;

  const ReaderChaptersList({
    super.key,
    required this.novel,
  });

  @override
  State<ReaderChaptersList> createState() => _ReaderChaptersListState();
}

class _ReaderChaptersListState extends State<ReaderChaptersList>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  String _authorName = '';

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int? _selectedChapterIndex;
  int _adRetryCount = 0;
  int? _earnedChapterIndex;
  int? _pendingAdChapterIndex;
  int? _earnedVoiceoverIndex;
  Map<String, dynamic>? _earnedVoiceoverData;

  static const int unlockDurationHours = 6;
  static const int maxAdRetries = 2;

  List<Map<String, dynamic>> _voiceovers = [];
  bool _isLoadingVoices = true;
  int? _selectedVoiceoverIndex;
  bool _isAdLoadingVoiceover = false;
  final Set<int> _unlockedChapterIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _earnedChapterIndex = null;
    _earnedVoiceoverIndex = null;
    _earnedVoiceoverData = null;
    _selectedChapterIndex = null;
    _selectedVoiceoverIndex = null;
    _loadChapters();
    _loadVoiceovers();
    _loadAuthorName();
    _preloadRewardedAd();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS) {
      AdMobLog.debug('[iOS] lifecycle: $state');
    }
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshUnlockStates();
      if (_rewardedAd == null &&
          !_isAdLoading &&
          !FullScreenAdCoordinator.instance.isFullScreenAdShowing) {
        _preloadRewardedAd();
      }
    }
  }

  Future<void> _refreshUnlockStates() async {
    final unlocked = <int>{};
    for (var i = 0; i < _chapters.length; i++) {
      if (await _isChapterUnlocked(i)) {
        unlocked.add(i);
      }
    }
    if (mounted) {
      setState(() => _unlockedChapterIndices
        ..clear()
        ..addAll(unlocked));
    }
  }

  Future<void> _loadVoiceovers() async {
    setState(() => _isLoadingVoices = true);
    final voiceovers = await SupabaseService.getVoiceoversForItem('novel', widget.novel.id);
    if (mounted) {
      setState(() {
        _voiceovers = voiceovers;
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _loadAuthorName() async {
    try {
      final response = await Supabase.instance.client
          .from('novels')
          .select('author_name')
          .eq('id', widget.novel.id)
          .single();
      
      setState(() {
        _authorName = response['author_name'] ?? 'Unknown Author';
      });
    } catch (e) {
      setState(() {
        _authorName = 'Unknown Author';
      });
    }
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);
    try {
      final chapters = await SupabaseService.getNovelChapters(widget.novel.id);
      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
      await _refreshUnlockStates();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chapters: $e')),
        );
      }
    }
  }

  // ... (Rest of ad logic unchanged down to build)
  
  Future<void> _saveUnlock(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockUntil =
        DateTime.now().add(const Duration(hours: unlockDurationHours));
    await prefs.setString(
        _unlockKey(chapterIndex), unlockUntil.toIso8601String());
    if (mounted) {
      setState(() => _unlockedChapterIndices.add(chapterIndex));
    }
  }
  
  void _showUnlockSuccessMessage() {
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Episode unlocked for 6 hours!")),
      );
    }
  }

  Future<bool> _isChapterUnlocked(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockString = prefs.getString(_unlockKey(chapterIndex));
    if (unlockString == null) return false;

    final unlockUntil = DateTime.tryParse(unlockString);
    if (unlockUntil == null) return false;

    return DateTime.now().isBefore(unlockUntil);
  }

  String _unlockKey(int index) => "novel_${widget.novel.id}_chapter_$index";

  void _preloadRewardedAd({bool isRetry = false}) {
    if (FullScreenAdCoordinator.instance.isFullScreenAdShowing) return;
    if (_rewardedAd != null && !isRetry) return;

    AdMobLog.debug('load start (rewarded)');
    setState(() => _isAdLoading = true);

    RewardedAd.load(
      adUnitId: Platform.isIOS 
          ? 'ca-app-pub-6924141712831128/8598444853' 
          : 'ca-app-pub-6924141712831128/8822036717',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          AdMobLog.debug('loaded (rewarded)');
          if (mounted) {
            setState(() {
              _rewardedAd = ad;
              _isAdLoading = false;
            });
          }
          print('✅ Rewarded ad loaded successfully');
          try {
            _logAdEvent('rewarded_loaded', {'isRetry': isRetry.toString()});
          } catch (_) {}
        },
        onAdFailedToLoad: (error) {
          if (mounted) {
            setState(() {
              _rewardedAd = null;
              _isAdLoading = false;
            });
          }
           print('❌ Rewarded ad failed to load: ${error.code} - ${error.message}');
          try {
            _logAdEvent('rewarded_failed_to_load', {'code': error.code, 'message': error.message});
          } catch (_) {}
        },
      ),
    );
  }

  void _showRewardedAd(int chapterIndex) async {
    _selectedChapterIndex = chapterIndex;

    if (_rewardedAd != null) {
      _showLoadedRewardedAd(chapterIndex);
      return;
    }

    if (_adRetryCount < maxAdRetries) {
      _adRetryCount++;
      setState(() => _isAdLoading = true);
      _showLoadingDialog();
      
      _preloadRewardedAd(isRetry: true);
      
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        Navigator.of(context).pop();
        
        if (_rewardedAd != null) {
          _showLoadedRewardedAd(chapterIndex);
        } else {
          if (_adRetryCount < maxAdRetries) {
            _showRewardedAd(chapterIndex); 
          } else {
            _showAdUnavailableDialog(chapterIndex);
          }
        }
      }
    } else {
      _showAdUnavailableDialog(chapterIndex);
    }
  }

  void _showLoadedRewardedAd(int chapterIndex) async {
    final ad = _rewardedAd;
    if (ad == null) return;

    _rewardedAd = null;
    _pendingAdChapterIndex = chapterIndex;

    final result = await FullScreenAdCoordinator.instance.showRewarded(
      ad,
      onUserEarnedReward: () async {
        await _saveUnlock(chapterIndex);
        _earnedChapterIndex = chapterIndex;
        try {
          await _logAdEvent('rewarded_earned', {'chapterIndex': chapterIndex});
        } catch (_) {}
      },
    );

    if (!mounted) return;

    _pendingAdChapterIndex = null;
    _selectedChapterIndex = null;
    _adRetryCount = 0;

    await FullScreenAdCoordinator.instance.runAfterDismiss(() async {
      if (!mounted) return;

      switch (result) {
        case FullScreenAdResult.dismissedWithReward:
          setState(() => _isAdLoading = false);
          _openEpisodeUnlockScreen(
            _chapters[chapterIndex],
            chapterIndex + 1,
          );
        case FullScreenAdResult.dismissedWithoutReward:
          setState(() => _isAdLoading = false);
          if (await _isChapterUnlocked(chapterIndex)) {
            _openEpisodeUnlockScreen(
              _chapters[chapterIndex],
              chapterIndex + 1,
            );
          }
        case FullScreenAdResult.failed:
          setState(() => _isAdLoading = false);
          await _unlockAndOpenChapter(chapterIndex);
        case FullScreenAdResult.dismissed:
        case FullScreenAdResult.skipped:
          setState(() => _isAdLoading = false);
      }
    });

    if (mounted) {
      FullScreenAdCoordinator.instance.schedulePreload(_preloadRewardedAd);
    }
  }

  Future<void> _unlockAndOpenChapter(int chapterIndex) async {
    await _saveUnlock(chapterIndex);
    final chapter = _chapters[chapterIndex];
    _openEpisodeUnlockScreen(chapter, chapterIndex + 1);
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D2144)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading ad...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait a moment',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdUnavailableDialog(int chapterIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ad Temporarily Unavailable'),
        content: const Text(
          'We\'re experiencing high traffic right now. You can unlock this episode without watching an ad this time.\n\nAds help us keep the app free - they\'ll be back soon!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _adRetryCount = 0; 
              _selectedChapterIndex = null;
              setState(() => _isAdLoading = false);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _adRetryCount = 0; 
              setState(() => _isAdLoading = false);
              await _unlockAndOpenChapter(chapterIndex);
            },
            child: const Text(
              'Unlock Free',
              style: TextStyle(color: Color(0xFF0D2144), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVoiceoverUnlock(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockUntil =
        DateTime.now().add(const Duration(hours: unlockDurationHours));
    await prefs.setString(
        _voiceoverUnlockKey(index), unlockUntil.toIso8601String());
    // Don't call setState or show SnackBar here - this is called during ad display
    // UI updates will happen after ad is dismissed
  }
  
  void _showVoiceoverUnlockSuccessMessage() {
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voiceover unlocked for 6 hours!")),
      );
    }
  }

  Future<void> _logAdEvent(String event, Map<String, dynamic> details) async {
    try {
      await FirebaseFirestore.instance.collection('ad_logs').add({
        'event': event,
        'novel_id': widget.novel.id,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
        ...details,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log ad event: $e');
    }
  }

  Future<bool> _isVoiceoverUnlocked(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockString = prefs.getString(_voiceoverUnlockKey(index));
    if (unlockString == null) return false;

    final unlockUntil = DateTime.tryParse(unlockString);
    if (unlockUntil == null) return false;

    return DateTime.now().isBefore(unlockUntil);
  }

  String _voiceoverUnlockKey(int index) => "novel_${widget.novel.id}_voiceover_$index";

  void _showVoiceoverRewardedAd(int index, Map<String, dynamic> voice) async {
    _selectedVoiceoverIndex = index;

    if (_rewardedAd != null) {
      _showLoadedVoiceoverRewardedAd(index, voice);
      return;
    }

    if (_adRetryCount < maxAdRetries) {
      _adRetryCount++;
      setState(() => _isAdLoadingVoiceover = true);
      _showLoadingDialog();
      
      _preloadRewardedAd(isRetry: true);
      
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        Navigator.of(context).pop();
        
        if (_rewardedAd != null) {
          _showLoadedVoiceoverRewardedAd(index, voice);
        } else {
          if (_adRetryCount < maxAdRetries) {
            _showVoiceoverRewardedAd(index, voice); 
          } else {
            _showAdUnavailableDialogVoiceover(index, voice);
          }
        }
      }
    } else {
      _showAdUnavailableDialogVoiceover(index, voice);
    }
  }

  void _showLoadedVoiceoverRewardedAd(int index, Map<String, dynamic> voice) async {
    final ad = _rewardedAd;
    if (ad == null) return;

    _rewardedAd = null;

    final result = await FullScreenAdCoordinator.instance.showRewarded(
      ad,
      onUserEarnedReward: () async {
        await _saveVoiceoverUnlock(index);
        _earnedVoiceoverIndex = index;
        _earnedVoiceoverData = voice;
        try {
          await _logAdEvent('rewarded_voiceover_earned', {'voiceIndex': index});
        } catch (_) {}
      },
    );

    if (!mounted) return;

    _selectedVoiceoverIndex = null;
    _adRetryCount = 0;

    await FullScreenAdCoordinator.instance.runAfterDismiss(() async {
      if (!mounted) return;

      switch (result) {
        case FullScreenAdResult.dismissedWithReward:
          setState(() => _isAdLoadingVoiceover = false);
          _showVoiceoverUnlockSuccessMessage();
          _openVoiceoverPlayer(
            voice['title'] ?? 'Part ${voice['part_number']}',
            voice['audio_url'],
          );
        case FullScreenAdResult.dismissedWithoutReward:
          setState(() => _isAdLoadingVoiceover = false);
          if (await _isVoiceoverUnlocked(index)) {
            _openVoiceoverPlayer(
              voice['title'] ?? 'Part ${voice['part_number']}',
              voice['audio_url'],
            );
          }
        case FullScreenAdResult.failed:
          setState(() => _isAdLoadingVoiceover = false);
          await _unlockAndOpenVoiceover(index, voice);
        case FullScreenAdResult.dismissed:
        case FullScreenAdResult.skipped:
          setState(() => _isAdLoadingVoiceover = false);
      }
    });

    _earnedVoiceoverIndex = null;
    _earnedVoiceoverData = null;

    if (mounted) {
      FullScreenAdCoordinator.instance.schedulePreload(_preloadRewardedAd);
    }
  }

  Future<void> _unlockAndOpenVoiceover(int index, Map<String, dynamic> voice) async {
    await _saveVoiceoverUnlock(index);
    _openVoiceoverPlayer(voice['title'] ?? 'Part ${voice['part_number']}', voice['audio_url']);
  }

  void _showAdUnavailableDialogVoiceover(int index, Map<String, dynamic> voice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ad Temporarily Unavailable'),
        content: const Text(
          'We\'re experiencing high traffic right now. You can unlock this voiceover without watching an ad this time.\n\nAds help us keep the app free - they\'ll be back soon!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _adRetryCount = 0; 
              _selectedVoiceoverIndex = null;
              setState(() => _isAdLoadingVoiceover = false);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _adRetryCount = 0; 
              setState(() => _isAdLoadingVoiceover = false);
              await _unlockAndOpenVoiceover(index, voice);
            },
            child: const Text(
              'Unlock Free',
              style: TextStyle(color: Color(0xFF0D2144), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openVoiceoverPlayer(String title, String audioUrl) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: false).push(
      MaterialPageRoute(
        builder: (_) => VoiceoverPlayerScreen(title: title, audioUrl: audioUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ScreenProtector removed to prevent iOS black screen
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.novel.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (_authorName.isNotEmpty)
              Text(
                'By: $_authorName',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: mainBlue.withOpacity(0.08),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Center(
                  child: Text(
                    "Watch an ad to unlock premium episodes and voiceovers",
                    style: TextStyle(
                      color: mainBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const TabBar(
                labelColor: mainBlue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: mainBlue,
                tabs: [
                  Tab(text: "Episodes", icon: Icon(Icons.menu_book)),
                  Tab(text: "Voiceovers", icon: Icon(Icons.headphones)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEpisodesTab(),
                    _buildVoiceoversTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodesTab() {
    const mainBlue = Color(0xFF0D2144);
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(mainBlue)),
      );
    }
    if (_chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No episodes available', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadChapters,
      color: mainBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chapters.length,
        itemBuilder: (context, index) {
          final chapter = _chapters[index];
          final unlocked = _unlockedChapterIndices.contains(index);
          final isLoadingThisChapter =
              _isAdLoading && _selectedChapterIndex == index;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text('Episode ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: mainBlue)),
              subtitle: unlocked
                  ? Text('Unlocked',
                      style: TextStyle(
                          color: Colors.green.shade700, fontSize: 12))
                  : const Text('Watch ad to unlock',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: unlocked
                  ? const Icon(Icons.lock_open, color: Colors.green)
                  : isLoadingThisChapter
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(mainBlue)))
                      : const Icon(Icons.lock, color: mainBlue),
              onTap: () {
                if (isLoadingThisChapter) return;
                if (unlocked) {
                  _openEpisodeUnlockScreen(chapter, index + 1);
                } else {
                  setState(() {
                    _selectedChapterIndex = index;
                  });
                  _showRewardedAd(index);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceoversTab() {
    const mainBlue = Color(0xFF0D2144);
    if (_isLoadingVoices) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(mainBlue)),
      );
    }
    if (_voiceovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No voiceovers available', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadVoiceovers,
      color: mainBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _voiceovers.length,
        itemBuilder: (context, index) {
          final voice = _voiceovers[index];
          return FutureBuilder<bool>(
            future: _isVoiceoverUnlocked(index),
            builder: (context, snapshot) {
              final unlocked = snapshot.data ?? false;
              final isLoadingThisVoiceover = _isAdLoadingVoiceover && _selectedVoiceoverIndex == index;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: mainBlue.withOpacity(0.1),
                    child: const Icon(Icons.play_circle_fill, color: mainBlue),
                  ),
                  title: Text(voice['title'] ?? 'Part ${voice['part_number']}', style: const TextStyle(fontWeight: FontWeight.bold, color: mainBlue)),
                  subtitle: unlocked
                      ? Text('Unlocked', style: TextStyle(color: Colors.green.shade700, fontSize: 12))
                      : const Text('Watch ad to listen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: unlocked
                      ? const Icon(Icons.headphones, color: Colors.green)
                      : isLoadingThisVoiceover
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(mainBlue)))
                          : const Icon(Icons.lock, color: mainBlue),
                  onTap: () async {
                    if (isLoadingThisVoiceover) return;
                    if (unlocked) {
                      _openVoiceoverPlayer(voice['title'] ?? 'Part ${voice['part_number']}', voice['audio_url']);
                    } else {
                      setState(() { _selectedVoiceoverIndex = index; });
                      _showVoiceoverRewardedAd(index, voice);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEpisodeUnlockScreen(Map<String, dynamic> chapter, int chapterNumber) {
    final chapterName = (chapter['name'] ?? 'Untitled').toString();
    final chapterContent = (chapter['content'] ?? '').toString();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: false).push(
      MaterialPageRoute(
        builder: (_) => EpisodeUnlockScreen(
          novel: widget.novel,
          chapterName: chapterName,
          chapterContent: chapterContent,
          chapterNumber: chapterNumber,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _refreshUnlockStates();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rewardedAd?.dispose();
    super.dispose();
  }
}