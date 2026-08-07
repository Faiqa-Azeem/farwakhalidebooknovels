import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/novel.dart';
import '../../utils/screen_protection_helper.dart';

class ChapterReaderScreen extends StatefulWidget {
  final Novel novel;
  final String chapterName;
  final String chapterContent;
  final int chapterNumber;

  const ChapterReaderScreen({
    super.key,
    required this.novel,
    required this.chapterName,
    required this.chapterContent,
    required this.chapterNumber,
    this.enableScreenProtection = false,
  });

  final bool enableScreenProtection;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen>
    with WidgetsBindingObserver {
  List<String> _pages = [];
  int _currentPage = 0;
  bool _isLoading = true;
  String _currentTheme = 'white_blue'; // default theme
  final TransformationController _transformationController = TransformationController();

  static const int _charsPerPage = 800;

  // Theme colors
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
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    _prepareChapterPages();
    if (widget.enableScreenProtection) {
      _secureScreen();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.enableScreenProtection &&
        mounted) {
      _secureScreen();
    }
  }

  Future<void> _secureScreen() async {
    if (!mounted || !widget.enableScreenProtection) return;
    await ScreenProtectionHelper.enableEpisodeContentProtection();
  }

  Future<void> _leaveReader() async {
    if (widget.enableScreenProtection) {
      await ScreenProtectionHelper.disableAll();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.dispose();
    if (widget.enableScreenProtection) {
      ScreenProtectionHelper.disableAll();
    }
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
    setState(() {
      _currentTheme = theme;
    });
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
    ).then((_) {
      if (widget.enableScreenProtection && mounted) {
        _secureScreen();
      }
    });
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
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'یہ ایک نمونہ متن ہے',
                    style: TextStyle(
                      fontFamily: 'JameelNooriNastaleeq',
                      color: textColor,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
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

  Future<void> _prepareChapterPages() async {
    setState(() => _isLoading = true);

    _pages = _splitContent(widget.chapterContent, _charsPerPage);

    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt(_bookmarkKey());

    if (savedPage != null && savedPage < _pages.length) {
      _currentPage = savedPage;
    } else {
      _currentPage = 0;
    }

    setState(() => _isLoading = false);
  }

  String _bookmarkKey() {
    return "chapter_${widget.novel.id}_${widget.chapterNumber}";
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

  Future<void> _saveBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_bookmarkKey(), _currentPage);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      _transformationController.value = Matrix4.identity();
      _saveBookmark();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _transformationController.value = Matrix4.identity();
      _saveBookmark();
    }
  }

  bool _isUrduText(String text) {
    final urduRegex = RegExp(r'[\u0600-\u06FF]');
    return urduRegex.hasMatch(text);
  }

  Color _getWatermarkColor() {
    if (_currentTheme == 'black_white') {
      // Darker watermark for black theme (harder to remove)
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _leaveReader();
        }
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveReader,
        ),
        title: Text(
          'Episode ${widget.chapterNumber}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showThemeDialog,
            tooltip: 'Change Theme',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: buttonColor,
                ),
              )
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
                                constrained: false, // Allows infinite height for scrolling
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
                                                  fontSize: 24, // Increased by 2 points
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
                                backgroundColor:
                                    _currentPage > 0 ? buttonColor : Colors.grey,
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
      painter: _PatternPainter(color: color),
      size: Size.infinite,
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;
  
  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const watermarkText = "Farwa Khalid E-Book Novels";

    final textStyle = TextStyle(
      color: color,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const double spacingX = 250;
    const double spacingY = 120;

    for (double y = 0; y < size.height; y += spacingY) {
      for (double x = 0; x < size.width; x += spacingX) {
        textPainter.text = TextSpan(text: watermarkText, style: textStyle);
        textPainter.layout();

        canvas.save();
        double offsetX = (y ~/ spacingY) % 2 == 0 ? 0 : -textPainter.width / 2;
        canvas.translate(x + offsetX, y);
        canvas.rotate(-0.3);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}