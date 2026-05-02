import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/ebook.dart';
import '../../utils/supabase_service.dart';
import 'voiceover_parts_screen.dart';

class WriterVoiceoverScreen extends StatefulWidget {
  const WriterVoiceoverScreen({super.key});

  @override
  State<WriterVoiceoverScreen> createState() => _WriterVoiceoverScreenState();
}

class _WriterVoiceoverScreenState extends State<WriterVoiceoverScreen> {
  final mainBlue = const Color(0xFF0D2144);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Voiceovers",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: mainBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Novels", icon: Icon(Icons.book)),
              Tab(text: "Ebooks", icon: Icon(Icons.menu_book_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNovelsTab(),
            _buildEbooksTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelsTab() {
    return FutureBuilder<List<Novel>>(
      // We will fetch from cache/network using SupabaseService
      future: SupabaseService.getAllNovels(page: 1, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: mainBlue));
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No novels found."));
        }

        final novels = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: novels.length,
          itemBuilder: (context, index) {
            final novel = novels[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: mainBlue.withOpacity(0.1),
                  child: Icon(Icons.book, color: mainBlue),
                ),
                title: Text(novel.title, style: TextStyle(fontWeight: FontWeight.bold, color: mainBlue)),
                subtitle: const Text("Manage voiceovers"),
                trailing: Icon(Icons.arrow_forward_ios, color: mainBlue, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceoverPartsScreen(
                        itemType: 'novel',
                        itemId: novel.id,
                        title: novel.title,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEbooksTab() {
    return FutureBuilder<List<Ebook>>(
      future: SupabaseService.getAllEbooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: mainBlue));
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No ebooks found."));
        }

        final ebooks = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ebooks.length,
          itemBuilder: (context, index) {
            final ebook = ebooks[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: mainBlue.withOpacity(0.1),
                  child: Icon(Icons.menu_book_outlined, color: mainBlue),
                ),
                title: Text(ebook.title, style: TextStyle(fontWeight: FontWeight.bold, color: mainBlue)),
                subtitle: const Text("Manage voiceovers"),
                trailing: Icon(Icons.arrow_forward_ios, color: mainBlue, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceoverPartsScreen(
                        itemType: 'ebook',
                        itemId: ebook.id,
                        title: ebook.title,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
