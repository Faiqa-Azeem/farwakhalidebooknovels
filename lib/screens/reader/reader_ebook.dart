import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/ebook.dart';
import '../../utils/supabase_service.dart';
import 'ebook_detail_screen.dart';

class ReaderEbook extends StatefulWidget {
  const ReaderEbook({super.key});

  @override
  State<ReaderEbook> createState() => _ReaderEbookState();
}

class _ReaderEbookState extends State<ReaderEbook>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Ebook> _ebooks = [];
  List<Ebook> _filteredEbooks = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _loadEbooks();
  }

  Future<void> _loadEbooks() async {
    setState(() => _isLoading = true);

    // ✅ 1. Always load cached ebooks first
    final box = Hive.box<LocalEbook>('offline_ebooks');
    final localEbooks = box.values.toList();

    if (localEbooks.isNotEmpty) {
      _ebooks = localEbooks
          .map((le) => Ebook(
                id: le.id,
                title: le.title,
                coverUrl: le.coverUrl,
                authorId: le.authorId,
              ))
          .toList();
      _filteredEbooks = _ebooks;
    }

    setState(() => _isLoading = false);

    // ✅ 2. Try online fetch in background
    try {
      final ebooks = await SupabaseService.getAllEbooks();

      // update cache
      await box.clear();
      for (var ebook in ebooks) {
        await box.put(
          ebook.id,
          LocalEbook(
            id: ebook.id,
            title: ebook.title,
            coverUrl: ebook.coverUrl,
            authorId: ebook.authorId,
            localFilePath: '',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _ebooks = ebooks;
          _filteredEbooks = ebooks;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Online fetch failed, showing cached ebooks.');
      if (_ebooks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No ebooks available offline.')),
          );
        }
      }
    }
  }

  void _searchEbooks(String query) async {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });

    try {
      List<Ebook> results;
      if (query.trim().isEmpty) {
        results = await SupabaseService.getAllEbooks();
      } else {
        results = await SupabaseService.searchEbooks(query);
      }

      if (mounted) {
        setState(() {
          _filteredEbooks = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ✅ Offline search
      final box = Hive.box<LocalEbook>('offline_ebooks');
      final localEbooks = box.values
          .where((le) =>
              le.title.toLowerCase().contains(query.toLowerCase()))
          .map((le) => Ebook(
                id: le.id,
                title: le.title,
                coverUrl: le.coverUrl,
                authorId: le.authorId,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _filteredEbooks = localEbooks;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search ebooks...',
                  prefixIcon: const Icon(Icons.search, color: mainBlue),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: mainBlue),
                          onPressed: () {
                            _searchController.clear();
                            _searchEbooks('');
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
                onChanged: _searchEbooks,
              ),
            ),

            // 📚 Ebooks Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(mainBlue),
                      ),
                    )
                  : _filteredEbooks.isEmpty
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
                                    ? 'No ebooks available'
                                    : 'No ebooks found for "$_searchQuery"',
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
                                    _searchEbooks('');
                                  },
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEbooks,
                          color: mainBlue,
                          child: GridView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _filteredEbooks.length,
                            itemBuilder: (context, index) {
                              final ebook = _filteredEbooks[index];
                              return _buildOptimizedEbookCard(ebook);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedEbookCard(Ebook ebook) {
    const mainBlue = Color(0xFF0D2144);

    return GestureDetector(
      onTap: () => _navigateToEbookDetail(ebook),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey.shade200,
                ),
                child: Stack(
                  children: [
                    () {
                      final url = ebook.coverUrl;

                      if (url == null) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.book_outlined, size: 48, color: Colors.grey),
                          );
                      }

                      return ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(mainBlue),
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
                          ),
                        );
                    }(),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ebook.status == 'Completed' 
                              ? Colors.black.withOpacity(0.7) 
                              : Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ebook.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ebook.status == 'Completed' ? Colors.greenAccent : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 68,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ebook.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: mainBlue,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEbookDetail(Ebook ebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EbookDetailScreen(ebook: ebook),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
