import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/novel.dart';
import '../../models/scene.dart';
import '../../utils/supabase_service.dart';
import '../../utils/screen_protection_helper.dart';
import 'reader_chapters_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screens/login_screen.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen>
    with AutomaticKeepAliveClientMixin {
  List<Scene> _scenes = [];
  bool _isLoading = true;
  String _authorName = '';
  final PageController _pageController = PageController(
    initialPage: 0,
    viewportFraction: 1.0,
    keepPage: true,
  );
  int _currentSceneIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ScreenProtectionHelper.disableAll();
    _loadAuthorName();
    _loadNovelContent();
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

  Future<void> _loadNovelContent() async {
    setState(() => _isLoading = true);
    try {
      final scenes = await SupabaseService.getNovelScenes(widget.novel.id);
      setState(() {
        _scenes = scenes;
        _isLoading = false;
        _currentSceneIndex = 0;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading novel content: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await ScreenProtectionHelper.disableAll();
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(mainBlue),
                ),
              )
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
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No scenes available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentSceneIndex = idx),
              itemCount: _scenes.length,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              itemBuilder: (context, index) {
                final scene = _scenes[index];
                return RepaintBoundary(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 500,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: _buildOptimizedSceneCard(scene),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              RepaintBoundary(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentSceneIndex > 0
                            ? () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                )
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
                                  curve: Curves.easeOut,
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onReadNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Read Now'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptimizedSceneCard(Scene scene) {
    const mainBlue = Color(0xFF0D2144);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scene.imageUrl != null)
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
                    final url = scene.imageUrl;
                    
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
                    scene.text,
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

  void _onReadNow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderChaptersList(novel: widget.novel),
      ),
    ).then((_) {
      if (mounted) {
        ScreenProtectionHelper.disableAll();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    ScreenProtectionHelper.disableAll();
    super.dispose();
  }
}