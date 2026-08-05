import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/supabase_service.dart';
import '../../utils/firebase_storage_service.dart';
import 'text_editor_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditNovelScreen extends StatefulWidget {
  const EditNovelScreen({super.key});

  @override
  State<EditNovelScreen> createState() => _EditNovelScreenState();
}

class _EditNovelScreenState extends State<EditNovelScreen> {
  String selectedType = 'Novel';
  bool isLoading = false;
  List<Map<String, dynamic>> uploads = [];
  Map<String, List<Map<String, dynamic>>> novelScenes = {};
  Map<String, List<Map<String, dynamic>>> novelChapters = {};
  Map<String, List<Map<String, dynamic>>> ebookScenes = {};
  Set<String> expandedItems = {}; // track expanded IDs

  @override
  void initState() {
    super.initState();
    fetchUploads();
  }

  Future<void> fetchUploads() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2';
      final table = selectedType == 'Novel' ? 'novels' : 'ebooks';
      
      final data = await supabase.from(table).select().eq('author_id', writerId);

      uploads = List<Map<String, dynamic>>.from(data);

      if (selectedType == 'Novel') {
        // OPTIMIZATION: Fetch all novel details in PARALLEL
        final List<Future<void>> fetchTasks = uploads.map((novel) async {
            final novelId = novel['id'] as String;
            
            // Fetch scenes and chapters in parallel for this novel
            final results = await Future.wait([
               supabase.from('scenes').select().eq('novel_id', novelId).order('ord'),
               supabase.from('chapters').select().eq('novel_id', novelId).order('ord'),
            ]);

            novelScenes[novelId] = List<Map<String, dynamic>>.from(results[0]);
            novelChapters[novelId] = List<Map<String, dynamic>>.from(results[1]);
        }).toList();

        await Future.wait(fetchTasks);

      } else {
        // OPTIMIZATION: Fetch all ebook details in PARALLEL
        final List<Future<void>> fetchTasks = uploads.map((ebook) async {
            final ebookId = ebook['id'] as String;
            
            final scenesData = await supabase
              .from('ebook_scenes')
              .select()
              .eq('ebook_id', ebookId)
              .order('ord');
            
            ebookScenes[ebookId] = List<Map<String, dynamic>>.from(scenesData);
        }).toList();

        await Future.wait(fetchTasks);
      }
    } catch (e) {
      debugPrint("Error fetching uploads: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load uploads")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteUpload(Map<String, dynamic> item) async {
    final supabase = Supabase.instance.client;
    final table = selectedType == 'Novel' ? 'novels' : 'ebooks';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Do you really want to delete '${item['title']}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Manual Cascade Delete
      if (selectedType == 'Ebook') {
        // Delete dependencies for Ebooks
        await supabase.from('ebook_access').delete().eq('ebook_id', item['id']);
        await supabase.from('ebook_scenes').delete().eq('ebook_id', item['id']);
        await supabase.from('ebook_content').delete().eq('ebook_id', item['id']);
        try {
          await supabase.from('ebook_payments').delete().eq('ebook_id', item['id']);
        } catch (_) {} // Ignore if table doesn't exist or other issue
      } else {
        // Delete dependencies for Novels
        await supabase.from('scenes').delete().eq('novel_id', item['id']);
        await supabase.from('chapters').delete().eq('novel_id', item['id']);
      }

      // 2. Delete Database Entry
      await supabase.from(table).delete().eq('id', item['id']);

      SupabaseService.clearSessionCache(); // Refresh readers
      
      // 2. Cleanup Storage (Background)
      _cleanupStorage(item['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'${item['title']}' deleted successfully")),
      );
      fetchUploads(); // refresh
    } catch (e) {
      debugPrint("Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  Future<void> _cleanupStorage(String id) async {
    try {
      final bucket = selectedType == 'Novel' ? 'novels' : 'ebooks';
      final storage = Supabase.instance.client.storage.from(bucket);

      // 1. Delete Cover Image (Pattern: $id.jpg)
      try {
        await storage.remove(['$id.jpg']);
      } catch (e) {
        // Ignore if not exists
      }

      // 2. Delete Scene Images (Folder: $id/...)
      // List files in the folder
      final List<FileObject> objects = await storage.list(path: id);
      
      if (objects.isNotEmpty) {
        final List<String> paths = objects.map((obj) => '$id/${obj.name}').toList();
        await storage.remove(paths);
      }

      // Check for subfolders if any (e.g. scenes/)
      // Supabase list is not recursive by default.
      // Based on upload logic: '$id/scenes/...'
      // The search in '$id' might find 'scenes' folder as an object?
      // Actually, list(path: '$id') will show contents of $id.
      // If there is a 'scenes' folder inside, it shows as object?
      // Let's try listing '$id/scenes' explicitly too.
      
      try {
         final List<FileObject> sceneObjects = await storage.list(path: '$id/scenes');
         if (sceneObjects.isNotEmpty) {
           final List<String> scenePaths = sceneObjects.map((obj) => '$id/scenes/${obj.name}').toList();
           await storage.remove(scenePaths);
         }
      } catch (e) {
        // ignore
      }

    } catch (e) {
      debugPrint("Cleanup storage error: $e");
    }
  }

  Future<void> deleteScene(String sceneId, String novelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Do you really want to delete this Scene?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('scenes').delete().eq('id', sceneId);
      novelScenes[novelId]?.removeWhere((s) => s['id'] == sceneId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scene deleted successfully")),
      );
    } catch (e) {
      debugPrint("Delete scene error: $e");
    }
  }

  Future<void> deleteEbookScene(String sceneId, String ebookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Do you really want to delete this E-book Scene?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('ebook_scenes').delete().eq('id', sceneId);
      ebookScenes[ebookId]?.removeWhere((s) => s['id'] == sceneId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-book scene deleted successfully")),
      );
    } catch (e) {
      debugPrint("Delete ebook scene error: $e");
    }
  }

  Future<void> deleteChapter(String chapterId, String novelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Do you really want to delete this Chapter?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('chapters').delete().eq('id', chapterId);
      novelChapters[novelId]?.removeWhere((c) => c['id'] == chapterId);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chapter deleted successfully")),
      );
    } catch (e) {
      debugPrint("Delete chapter error: $e");
    }
  }

  Future<void> updateNovelCover(Map<String, dynamic> novel) async {
    final imageFile = await pickImage();
    if (imageFile == null) return;

    try {
      final novelId = novel['id'] as String;
      final coverPath =
          'novels/$novelId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final coverUrl =
          await FirebaseStorageService.uploadFile(imageFile, coverPath);
      if (coverUrl == null) {
        throw Exception('Cover upload failed');
      }

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('novels').update({
        'cover_url': coverUrl,
        'updated_at': now,
      }).eq('id', novelId);

      await SupabaseService.clearSessionCache();

      setState(() {
        novel['cover_url'] = coverUrl;
        novel['updated_at'] = now;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Novel cover updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cover: $e')),
        );
      }
    }
  }

  String? _coverDisplayUrl(Map<String, dynamic> item) {
    final url = item['cover_url'] as String?;
    if (url == null || url.isEmpty) return null;
    final updatedAt = item['updated_at']?.toString() ?? '';
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$updatedAt';
  }

  Widget? _buildCoverThumb(Map<String, dynamic> item) {
    final url = _coverDisplayUrl(item);
    if (url == null) {
      return const CircleAvatar(
        child: Icon(Icons.book_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
          width: 48,
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => const CircleAvatar(
          child: Icon(Icons.book_outlined),
        ),
      ),
    );
  }

  // ✅ ADDED MISSING METHODS
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<void> addScene(String parentId, bool isEbook) async {
    final File? imageFile = await pickImage();
    if (imageFile == null) return; 

    final newText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const TextEditorScreen(
          type: "Scene",
          count: 1,
          initialContent: "",
        ),
      ),
    );

    if (newText == null || newText.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2';
      final table = isEbook ? 'ebook_scenes' : 'scenes';
      final idField = isEbook ? 'ebook_id' : 'novel_id';
      final bucketName = isEbook ? 'ebooks' : 'novels';

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final path = '$parentId/Scenes/$fileName'; 
      await supabase.storage.from(bucketName).upload(path, imageFile);
      final imageUrl = supabase.storage.from(bucketName).getPublicUrl(path);

      final maxOrdRes = await supabase
          .from(table)
          .select('ord')
          .eq(idField, parentId)
          .order('ord', ascending: false)
          .limit(1)
          .maybeSingle();

      int newOrd = 1;
      if (maxOrdRes != null && maxOrdRes['ord'] != null) {
        newOrd = (maxOrdRes['ord'] as int) + 1;
      }

      await supabase.from(table).insert({
        'text': newText,
        'image_url': imageUrl,
        idField: parentId,
        'author_id': writerId,
        'ord': newOrd,
      });

      await fetchUploads(); // Refresh to show new scene
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Scene added successfully")));
    } catch (e) {
      debugPrint("Add scene error: $e");
    }
  }

  Future<void> addChapter(String novelId) async {
    final newName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const TextEditorScreen(
          type: "Chapter Name",
          count: 1,
          initialContent: "",
        ),
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2';

      final maxOrdRes = await supabase
          .from('chapters')
          .select('ord')
          .eq('novel_id', novelId)
          .order('ord', ascending: false)
          .limit(1)
          .maybeSingle();

      int newOrd = 1;
      if (maxOrdRes != null && maxOrdRes['ord'] != null) {
        newOrd = (maxOrdRes['ord'] as int) + 1;
      }

      final inserted = await supabase
          .from('chapters')
          .insert({
        'name': newName,
        'content': '',
        'novel_id': novelId,
        'author_id': writerId,
        'ord': newOrd,
      })
          .select()
          .single();

      novelChapters[novelId]?.add(inserted);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chapter added successfully")));
    } catch (e) {
      debugPrint("Add chapter error: $e");
    }
  }

  Future<void> updateStatus(Map<String, dynamic> item, String newStatus) async {
    final supabase = Supabase.instance.client;
    final table = selectedType == 'Novel' ? 'novels' : 'ebooks';
    try {
      await supabase.from(table).update({'status': newStatus}).eq('id', item['id']);
      
      SupabaseService.clearSessionCache(); // Refresh readers
      
      setState(() {
        item['status'] = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status updated to $newStatus")),
      );
    } catch (e) {
      debugPrint("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedType == 'Novel' ? 'Delete Novel' : 'Delete E-book',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Choice Chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Novels"),
                  selected: selectedType == 'Novel',
                  onSelected: (_) {
                    setState(() => selectedType = 'Novel');
                    fetchUploads();
                  },
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("E-books"),
                  selected: selectedType == 'Ebook',
                  onSelected: (_) {
                    setState(() => selectedType = 'Ebook');
                    fetchUploads();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : uploads.isEmpty
                ? const Center(child: Text("No uploads found"))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100), // ✅ Fix Scrolling Issue
              itemCount: uploads.length,
              itemBuilder: (context, index) {
                final item = uploads[index];
                final id = item['id'] as String;

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: selectedType == 'Novel'
                            ? _buildCoverThumb(item)
                            : null,
                        title: Text(item['title'] ?? 'Untitled'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                expandedItems.contains(id)
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (expandedItems.contains(id)) {
                                    expandedItems.remove(id);
                                  } else {
                                    expandedItems.add(id);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () => deleteUpload(item),
                            ),
                          ],
                        ),
                      ),
                      if (expandedItems.contains(id)) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: item['status'] as String? ?? 'Completed',
                                items: const [
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                  DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                                ],
                                onChanged: (val) {
                                  if (val != null) updateStatus(item, val);
                                },
                              ),
                            ],
                          ),
                        ),
                        if (selectedType == 'Novel') ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => updateNovelCover(item),
                                icon: const Icon(Icons.photo),
                                label: Text(
                                  item['cover_url'] != null
                                      ? 'Update Cover'
                                      : 'Add Cover',
                                ),
                              ),
                            ),
                          ),
                          // Scenes
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Text("Scenes",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                ...?novelScenes[id]?.map((scene) {
                                  final sceneText =
                                      (scene['text'] ?? '')
                                          .toString()
                                          .split('\n')
                                          .first;
                                  return Card(
                                    color: mainBlue,
                                    margin:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: ListTile(
                                      title: Text(
                                        sceneText.isEmpty
                                            ? "Untitled Scene"
                                            : sceneText,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      trailing: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                          Colors.white,
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                        onPressed: () => deleteScene(
                                            scene['id'], id),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          // Chapters
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Text("Chapters",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                ...?novelChapters[id]
                                    ?.map((chapter) {
                                  return Card(
                                    color: mainBlue,
                                    margin:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: ListTile(
                                      title: Text(
                                        chapter['name'] ??
                                            "Untitled Chapter",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      trailing: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                          Colors.white,
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                        onPressed: () =>
                                            deleteChapter(
                                                chapter['id'], id),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ] else ...[
                          // E-book Scenes only
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Text("E-book Scenes",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                ...?ebookScenes[id]?.map((scene) {
                                  final sceneText =
                                      (scene['text'] ?? '')
                                          .toString()
                                          .split('\n')
                                          .first;
                                  return Card(
                                    color: mainBlue,
                                    margin:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: ListTile(
                                      title: Text(
                                        sceneText.isEmpty
                                            ? "Untitled Scene"
                                            : sceneText,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      trailing: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                          Colors.white,
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                        onPressed: () =>
                                            deleteEbookScene(
                                                scene['id'], id),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ]
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
