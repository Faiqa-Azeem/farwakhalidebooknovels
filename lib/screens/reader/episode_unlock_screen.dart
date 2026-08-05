import 'package:flutter/material.dart';
import '../../models/novel.dart';
import 'chapter_reader_screen.dart';

/// Shown after a rewarded ad unlocks an episode (iOS and Android).
/// Keeps screen protection off this page so ads and protection never overlap.
class EpisodeUnlockScreen extends StatelessWidget {
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

  void _openReader(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          novel: novel,
          chapterName: chapterName,
          chapterContent: chapterContent,
          chapterNumber: chapterNumber,
          enableScreenProtection: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Episode $chapterNumber'),
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
                'You can now read Episode $chapterNumber.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                novel.title,
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
                  onPressed: () => _openReader(context),
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
