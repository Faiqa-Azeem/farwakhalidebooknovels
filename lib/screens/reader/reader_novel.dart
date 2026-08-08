import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/novel.dart';
import '../../utils/ad_flow_helper.dart';
import '../../utils/ad_recovery_utils.dart';
import '../../utils/screen_protection_helper.dart';
import '../../utils/supabase_service.dart';
import 'novel_detail_screen.dart';

class ReaderNovel extends StatefulWidget {
  const ReaderNovel({super.key});

  @override
  State<ReaderNovel> createState() => _ReaderNovelState();
}

class _ReaderNovelState extends State<ReaderNovel> with WidgetsBindingObserver {
  Key _surfaceKey = UniqueKey();
  final TextEditingController _searchController = TextEditingController();
  List<Novel> _novels = [];
  List<Novel> _filteredNovels = [];
  bool _isLoading = true;
  String _searchQuery = '';

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  Novel? _selectedNovel;

  static const int adCooldownMinutes = 5;
  static String get adUnitId => Platform.isIOS 
      ? 'ca-app-pub-6924141712831128/2224608196' 
      : 'ca-app-pub-6924141712831128/4882791708';

  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isMoreLoading = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNovels(refresh: true);
    _loadInterstitialAd();
    _scrollController.addListener(_onScroll);
    ScreenProtectionHelper.disableAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    _interstitialAd?.dispose();
    ScreenProtectionHelper.disableAll();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ScreenProtectionHelper.disableAll();
      if (mounted) {
        recoverAfterFullScreenAd(context: context);
        setState(() => _surfaceKey = UniqueKey());
      }
      if (_interstitialAd == null && !_isAdLoading && mounted) {
        _loadInterstitialAd();
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        _hasMore && 
        _searchQuery.isEmpty) { // Don't paginate search results for now
      _loadMoreNovels();
    }
  }

  Future<void> _loadNovels({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _novels = []; // Clear current list on refresh
      });
    }

    try {
      if (refresh) {
        await SupabaseService.clearSessionCache();
      }
      final novels = await SupabaseService.getAllNovels(
        page: 1,
        limit: _pageSize,
        forceRefresh: refresh,
      );
      setState(() {
        _novels = novels;
        _filteredNovels = novels;
        _isLoading = false;
        // If we got fewer than limit, we reached the end
        if (novels.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading novels: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreNovels() async {
    if (_isMoreLoading || !_hasMore) return;

    setState(() => _isMoreLoading = true);
    
    try {
      final nextPage = _currentPage + 1;
      final newNovels = await SupabaseService.getAllNovels(page: nextPage, limit: _pageSize);
      
      setState(() {
         if (newNovels.isEmpty) {
           _hasMore = false;
         } else {
           _currentPage = nextPage;
           _novels.addAll(newNovels);
           _filteredNovels = _novels;
           
           if (newNovels.length < _pageSize) {
             _hasMore = false;
           }
         }
         _isMoreLoading = false;
      });
    } catch (e) {
      setState(() => _isMoreLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more novels: $e')),
        );
      }
    }
  }

  void _searchNovels(String query) async {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });

    try {
      List<Novel> results;
      if (query.trim().isEmpty) {
        // If clearing search, reload initial (or cached) list
        // Reuse _novels if available, but simplest is to just re-fetch page 1 or show current
         if (_novels.isNotEmpty) {
           results = _novels;
         } else {
           await _loadNovels(refresh: true);
           return;
         }
      } else {
        results = await SupabaseService.searchNovels(query);
      }

      setState(() {
        _filteredNovels = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching novels: $e')),
        );
      }
    }
  }

  // ✅ IMPROVED: Clean ad loading with proper state management
  void _loadInterstitialAd() {
    if (_isAdLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isAdLoading = true);

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Interstitial ad loaded successfully');
          if (mounted) {
            setState(() {
              _interstitialAd = ad;
              _isAdLoading = false;
            });
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (error) {
          print('❌ Interstitial ad failed to load: ${error.code} - ${error.message}');
          if (mounted) {
            setState(() {
              _interstitialAd = null;
              _isAdLoading = false;
            });
          }
        },
      ),
    );
  }

  Future<bool> _canShowAd(Novel novel) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownString = prefs.getString('novel_ad_${novel.id}');
    if (lastShownString == null) return true;

    final lastShown = DateTime.tryParse(lastShownString);
    if (lastShown == null) return true;

    return DateTime.now().difference(lastShown) >
        const Duration(minutes: adCooldownMinutes);
  }

  Future<void> _markAdShown(Novel novel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('novel_ad_${novel.id}', DateTime.now().toIso8601String());
  }

  // ✅ FIXED: Strict Ad Logic - Wait for Ad or Show Error
  void _showInterstitialAd(Novel novel) async {
    // 1. Check cooldown first
    final canShow = await _canShowAd(novel);
    if (!canShow) {
      print('⏰ Ad cooldown active for ${novel.title}, navigating directly');
      _navigateToNovelDetail(novel);
      return;
    }

    _selectedNovel = novel;

    // 2. If ad is ready, show it immediately
    if (_interstitialAd != null) {
      print('📺 Showing loaded ad');
      _showLoadedAd();
      return;
    }

    // 3. Ad not ready - Force a load with visual feedback
    print('⏳ Ad not ready. Showing loading dialog to user...');
    _showLoadingDialog(); // Show "Loading Ad..." dialog

    // Attempt to load ad
    _loadInterstitialAd();

    // Wait loop: Check every 500ms for up to 4 seconds
    for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_interstitialAd != null) {
           break; // Ad loaded!
        }
    }

    // Close loading dialog
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // 4. Final Decision
    if (_interstitialAd != null) {
      print('✅ Ad loaded during wait, showing now');
      _showLoadedAd();
    } else {
      // Still failed after waiting 4 seconds?
      print('⚠️ Ad failed to load after waiting. Allowing access as fallback.');
      if (mounted) {
         // Optional: Show a toast "Ad unavailable, skipping..."
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Ad unavailable, opening novel...')),
         );
      }
      if (_selectedNovel != null) {
        _navigateToNovelDetail(_selectedNovel!);
      }
    }
  }

  // ✅ IMPROVED: Clean ad display with proper callbacks - FIXED for iOS blank screen
  void _showLoadedAd() async {
    if (_interstitialAd == null) return;

    await AdFlowHelper.presentFullScreenAd(
      context: context,
      showAd: () async {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) {
            print('📺 Ad displayed');
          },
          onAdDismissedFullScreenContent: (ad) async {
            print('✅ Ad dismissed, navigating to detail');
            ad.dispose();
            _interstitialAd = null;

            final novel = _selectedNovel;
            if (novel == null || !mounted) return;

            await AdFlowHelper.completeAfterDismiss(
              context: context,
              preloadNextAd: _loadInterstitialAd,
              continueFlow: () async {
                if (!mounted) return;
                if (mounted) setState(() => _surfaceKey = UniqueKey());
                await _markAdShown(novel);
                _navigateToNovelDetail(novel);
              },
            );
          },
          onAdFailedToShowFullScreenContent: (ad, error) async {
            print('❌ Ad failed to show: ${error.code} - ${error.message}');
            ad.dispose();
            _interstitialAd = null;

            final novel = _selectedNovel;
            if (novel == null) return;

            await AdFlowHelper.completeAfterDismiss(
              context: context,
              preloadNextAd: _loadInterstitialAd,
              continueFlow: () async {
                if (mounted) _navigateToNovelDetail(novel);
              },
            );
          },
        );

        _interstitialAd!.show();
      },
    );
  }

  // ✅ IMPROVED: Protected loading dialog
  void _showLoadingDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      key: _surfaceKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search novels...',
                  prefixIcon: const Icon(Icons.search, color: mainBlue),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: mainBlue),
                          onPressed: () {
                            _searchController.clear();
                            _searchNovels('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: mainBlue, width: 2),
                  ),
                ),
                onChanged: _searchNovels,
              ),
            ),
            
            // 🐛 DEBUG: Temporary button to clear cache if needed
            // Remove this before production release if desired
            if (_novels.isEmpty && !_isLoading)
              TextButton.icon(
                onPressed: () async {
                  final box = await Hive.openBox('novels_cache');
                  await box.clear();
                  SupabaseService.sessionCache.clear(); // Clear session cache too
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared! Refreshing...')),
                  );
                  _loadNovels(refresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Force Refresh (Clear Cache)"),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(mainBlue),
                      ),
                    )
                  : _filteredNovels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No novels available'
                                    : 'No novels found for "$_searchQuery"',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchNovels('');
                                  },
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadNovels(refresh: true),
                          color: mainBlue,
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.50,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _filteredNovels.length + (_isMoreLoading ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _filteredNovels.length) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(mainBlue),
                                  ),
                                );
                              }
                              final novel = _filteredNovels[index];
                              return _buildNovelCard(novel);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelCard(Novel novel) {
    const mainBlue = Color(0xFF0D2144);

    return GestureDetector(
      onTap: () {
        // ✅ FIXED: Removed _isAdLoading block - always allow navigation
        _showInterstitialAd(novel);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: AspectRatio(
                aspectRatio: 819 / 1280,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                      ),
                      child: novel.displayCoverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: novel.displayCoverUrl!,
                              cacheKey: '${novel.id}_${novel.updatedAt.millisecondsSinceEpoch}',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
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
                                  Icons.book_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.book_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: novel.status == 'Completed' 
                              ? Colors.black.withOpacity(0.7) 
                              : Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          novel.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: novel.status == 'Completed' ? Colors.greenAccent : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAdaptiveTitle(novel.title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNovelDetail(Novel novel) async {
    if (!mounted) return;
    
    // ✅ FIXED: No delay - navigate immediately after ad dismissal
    if (!mounted) return;
    
    // ✅ FIXED: Use regular push to maintain navigation stack
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NovelDetailScreen(novel: novel),
      ),
    );

    await ScreenProtectionHelper.disableAll();
    if (mounted) setState(() {});
  }

  Widget _buildAdaptiveTitle(String title) {
    const mainBlue = Color(0xFF0D2144);
    
    // Calculate appropriate font size based on title length
    double fontSize;
    int maxLines;
    
    if (title.length <= 20) {
      fontSize = 14;
      maxLines = 2;
    } else if (title.length <= 35) {
      fontSize = 12;
      maxLines = 3;
    } else if (title.length <= 50) {
      fontSize = 11;
      maxLines = 3;
    } else {
      fontSize = 10;
      maxLines = 4;
    }
    
    return Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: mainBlue,
        height: 1.2,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }


}