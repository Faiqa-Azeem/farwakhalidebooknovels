import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../utils/screen_protection_helper.dart';
import 'chapter_reader_screen.dart';

/// Shown after a rewarded ad unlocks an episode (iOS and Android).
/// No screen protection here — only on the reader after Read Now.
class EpisodeUnlockScreen extends StatefulWidget {
  final Novel novel;
  final String chapterName;
  final String chapterContent;
  final int chapterNumber;

  const EpisodeUnlockScreen({
    super.key,
    required this.novel,
    required this.chapterName,
    required this.chapterContent,
    required this.chapterNumber,
  });

  @override
  State<EpisodeUnlockScreen> createState() => _EpisodeUnlockScreenState();
}

class _EpisodeUnlockScreenState extends State<EpisodeUnlockScreen> {
  @override
  void initState() {
    super.initState();
    ScreenProtectionHelper.disableForAdFlow();
  }

  Future<void> _openReader() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          novel: widget.novel,
          chapterName: widget.chapterName,
          chapterContent: widget.chapterContent,
          chapterNumber: widget.chapterNumber,
          enableScreenProtection: true,
        ),
      ),
    );

    if (mounted) {
      await ScreenProtectionHelper.disableForAdFlow();
    }
  }

  @override
  void dispose() {
    ScreenProtectionHelper.forceDisableForAdFlow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Episode ${widget.chapterNumber}'),
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Episode Unlocked!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: mainBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You can now read Episode ${widget.chapterNumber}.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.novel.title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openReader,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text(
                    'Read Now',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
