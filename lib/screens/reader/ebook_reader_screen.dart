import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ebook.dart';
import '../../utils/screen_protection_helper.dart';
import '../../utils/supabase_service.dart';

class EbookReaderScreen extends StatefulWidget {
  final Ebook ebook;
  const EbookReaderScreen({super.key, required this.ebook});

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  // Data
  List<String> _pages = [];
  bool _isLoading = true;
  int _currentPage = 0;
  String _currentTheme = 'white_blue';
  
  // Logic from ChapterReaderScreen
  static const int _charsPerPage = 500; // Updated to 500 as requested
  final TransformationController _transformationController = TransformationController();

  // Themes
  final Map<String, Map<String, Color>> _themes = {
    'white_blue': {
      'background': Colors.white,
      'text': Colors.black87,
      'appBar': const Color(0xFF0D2144),
      'button': const Color(0xFF0D2144),
    },
    'black_white': {
      'background': Colors.black,
      'text': Colors.white,
      'appBar': Colors.black,
      'button': Colors.grey.shade800,
    },
    'beige': {
      'background': const Color(0xFFF5E6D3),
      'text': const Color(0xFF3E2723),
      'appBar': const Color(0xFF8D6E63),
      'button': const Color(0xFF8D6E63),
    },
  };

  @override
  void initState() {
    super.initState();
    ScreenProtectionHelper.disableAll();
    _loadTheme();
    _loadEbookContent();
  }

  @override
  void dispose() {
    ScreenProtectionHelper.disableAll();
    _saveProgress(); 
    _transformationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('reader_theme') ?? 'white_blue';
    });
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_theme', theme);
    setState(() => _currentTheme = theme);
  }

  // --- Content Loading & Splitting ---
  Future<void> _loadEbookContent() async {
    setState(() => _isLoading = true);

    try {
      String fullContent = "";
      
      final connectivity = await Connectivity().checkConnectivity();
      bool isOnline = connectivity != ConnectivityResult.none;

      if (isOnline) {
        // 1. Try to fetch FULL CONTENT first (User's preferred source of truth)
        try {
           final raw = await SupabaseService.getEbookContent(widget.ebook.id);
           if (raw != null && raw.isNotEmpty) {
             fullContent = raw;
           } else {
             // 2. Fallback to Scenes if full content is missing
             final scenesResponse = await Supabase.instance.client
                  .from('ebook_scenes')
                  .select('text')
                  .eq('ebook_id', widget.ebook.id)
                  .order('ord', ascending: true);
             
              if (scenesResponse.isNotEmpty) {
                 fullContent = scenesResponse
                     .map((s) => s['text'] as String?)
                     .where((t) => t != null && t.isNotEmpty)
                     .join("\n\n");
              }
           }
        } catch (e) {
          debugPrint("Fetch error: $e");
        }
      }

      if (fullContent.isEmpty) {
        final offline = await _readOffline(widget.ebook.id);
        if (offline != null) fullContent = offline;
      }

      // Split content exactly like ChapterReaderScreen
      if (fullContent.isNotEmpty) {
        _pages = _splitContent(fullContent, _charsPerPage);
        
        // Save for offline if online success
        if (isOnline && fullContent.isNotEmpty) {
          _writeOffline(widget.ebook.id, fullContent);
        }
      } else {
        _pages = [];
      }

      setState(() {
        _isLoading = false;
        _loadProgress();
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pages = [];
      });
    }
  }

  List<String> _splitContent(String text, int chunkSize) {
    final List<String> chunks = [];
    int start = 0;

    while (start < text.length) {
      int end = start + chunkSize;
      if (end >= text.length) {
        end = text.length;
      } else {
         int lastSpace = text.lastIndexOf(' ', end);
         if (lastSpace > start) {
           end = lastSpace;
         }
      }
      chunks.add(text.substring(start, end).trim());
      start = end;
    }
    return chunks;
  }

  /* ----------  Offline helpers  ---------- */
  Future<File> _localFile(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ebook_$bookId.txt');
  }
  
  Future<void> _writeOffline(String bookId, String text) async {
    try {
      final file = await _localFile(bookId);
      await file.writeAsString(text);
    } catch (_) {}
  }

  Future<String?> _readOffline(String bookId) async {
    try {
      final file = await _localFile(bookId);
      if (await file.exists()) return file.readAsString();
    } catch (_) {}
    return null;
  }

  /* -------------- Progress -------------- */
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int savedIndex = prefs.getInt('ebook_progress_${widget.ebook.id}') ?? 0;
      if (savedIndex < 0) savedIndex = 0;
      if (savedIndex >= _pages.length) savedIndex = 0;
      
      setState(() => _currentPage = savedIndex);
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ebook_progress_${widget.ebook.id}', _currentPage);
  }

  /* -------------- Navigation -------------- */
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
      _transformationController.value = Matrix4.identity();
      _saveProgress();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _transformationController.value = Matrix4.identity();
      _saveProgress();
    }
  }
  
  bool _isUrduText(String text) {
    final urduRegex = RegExp(r'[\u0600-\u06FF]');
    return urduRegex.hasMatch(text);
  }

  Color _getWatermarkColor() {
    if (_currentTheme == 'black_white') {
      return Colors.white.withOpacity(0.35);
    }
    final textColor = _themes[_currentTheme]!['text']!;
    return textColor.withOpacity(0.15);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _themes[_currentTheme]!['background']!;
    final textColor = _themes[_currentTheme]!['text']!;
    final appBarColor = _themes[_currentTheme]!['appBar']!;
    final buttonColor = _themes[_currentTheme]!['button']!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.ebook.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette), 
            onPressed: _showThemeDialog,
          ),
          IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: _loadEbookContent,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: buttonColor))
            : _pages.isEmpty
                ? Center(
                    child: Text(
                      "No content available",
                      style: TextStyle(color: textColor),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: 1.0,
                                maxScale: 4.0,
                                constrained: false, // Matches ChapterReaderScreen
                                panEnabled: true,
                                scaleEnabled: true,
                                child: Container(
                                  width: constraints.maxWidth,
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.topLeft,
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: WatermarkPattern(
                                            color: _getWatermarkColor(),
                                          ),
                                        ),
                                      ),
                                       Builder(
                                         builder: (context) {
                                           final safePage = (_currentPage >= 0 && _currentPage < _pages.length) ? _currentPage : 0;
                                           final pageText = _pages.isNotEmpty ? _pages[safePage] : '';
                                           return GestureDetector(
                                             onLongPress: () {},
                                             child: Directionality(
                                               textDirection: TextDirection.rtl,
                                               child: Text(
                                                 pageText,
                                                 style: TextStyle(
                                                   fontFamily: _isUrduText(pageText)
                                                       ? 'JameelNooriNastaleeq'
                                                       : 'Poppins',
                                                   fontSize: 32, // Increased from 29 as requested
                                                   height: 1.8,
                                                   color: textColor,
                                                 ),
                                                 textAlign: TextAlign.right,
                                               ),
                                             ),
                                           );
                                         },
                                       ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _previousPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentPage > 0 ? buttonColor : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Previous"),
                            ),
                            Text(
                              "${_currentPage + 1} / ${_pages.length}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentPage < _pages.length - 1
                                    ? buttonColor
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Next"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Theme',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildThemePreview('White & Blue', 'white_blue', Colors.white, Colors.black87),
              const SizedBox(height: 12),
              _buildThemePreview('Black & White', 'black_white', Colors.black, Colors.white),
              const SizedBox(height: 12),
              _buildThemePreview('Beige', 'beige', const Color(0xFFF5E6D3), const Color(0xFF3E2723)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePreview(String name, String themeKey, Color bgColor, Color textColor) {
    final isSelected = _currentTheme == themeKey;
    return GestureDetector(
      onTap: () {
        _saveTheme(themeKey);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  Text(
                    'Preview Text',
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
          ],
        ),
      ),
    );
  }
}

class WatermarkPattern extends StatelessWidget {
  final Color color;
  const WatermarkPattern({super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WatermarkPainter(color),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final Color color;
  _WatermarkPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    const text = 'Farwa Khalid E-Book Novels';
    final style = TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    const spacingX = 250;
    const spacingY = 150; // Increased spacing slightly to match ChapterReaderScreen loose look if needed, but 120/250 vs 150/250 is minor.
    
    for (double y = 0; y < size.height; y += spacingY) {
      for (double x = 0; x < size.width; x += spacingX) {
        canvas.save();
        canvas.translate(x + (y % 2 == 0 ? 0 : 100), y);
        canvas.rotate(-0.2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}