import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'text_editor_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for compute
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../utils/supabase_service.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  String selectedType = 'Novel';
  bool isLoading = false;
  List<Map<String, dynamic>> uploads = [];
  Map<String, List<Map<String, dynamic>>> novelScenes = {};
  Map<String, List<Map<String, dynamic>>> novelChapters = {};
  Map<String, List<Map<String, dynamic>>> ebookScenes = {};
  Map<String, List<Map<String, dynamic>>> ebookContent = {}; // NEW
  Set<String> expandedItems = {};
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }


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
      final data =
      await supabase.from(table).select().eq('author_id', writerId);

      uploads = List<Map<String, dynamic>>.from(data);

      if (selectedType == 'Novel') {
        for (var novel in uploads) {
          final novelId = novel['id'] as String;

          final scenesData = await supabase
              .from('scenes')
              .select()
              .eq('novel_id', novelId)
              .order('ord');
          novelScenes[novelId] = List<Map<String, dynamic>>.from(scenesData);

          final chaptersData = await supabase
              .from('chapters')
              .select()
              .eq('novel_id', novelId)
              .order('ord');
          novelChapters[novelId] =
          List<Map<String, dynamic>>.from(chaptersData);
        }
      } else {
        for (var ebook in uploads) {
          final ebookId = ebook['id'] as String;

          final ebookScenesData = await supabase
              .from('ebook_scenes')
              .select()
              .eq('ebook_id', ebookId)
              .order('ord');
          ebookScenes[ebookId] =
          List<Map<String, dynamic>>.from(ebookScenesData);

          final ebookContentData = await supabase
              .from('ebook_content')
              .select()
              .eq('ebook_id', ebookId)
          ;

          ebookContent[ebookId] =
          List<Map<String, dynamic>>.from(ebookContentData);
        }
      }
    } catch (e) {
      debugPrint("Error fetching uploads: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load uploads")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> editScene(
      Map<String, dynamic> scene, String parentId, bool isEbook) async {
    final newText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          type: "Scene",
          count: 1,
          initialContent: scene['text'],
        ),
      ),
    );

    if (newText == null) return;

    try {
      final supabase = Supabase.instance.client;
      final table = isEbook ? 'ebook_scenes' : 'scenes';

      await supabase.from(table).update({'text': newText}).eq('id', scene['id']);

      if (isEbook) {
        final list = ebookScenes[parentId];
        if (list != null) {
          final idx = list.indexWhere((s) => s['id'] == scene['id']);
          if (idx != -1) list[idx]['text'] = newText;
        }
      } else {
        final list = novelScenes[parentId];
        if (list != null) {
          final idx = list.indexWhere((s) => s['id'] == scene['id']);
          if (idx != -1) list[idx]['text'] = newText;
        }
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scene updated successfully")),
      );
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> editChapterName(
      Map<String, dynamic> chapter, String novelId) async {
    final newName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          type: "Chapter Name",
          count: 1,
          initialContent: chapter['name'],
        ),
      ),
    );

    if (newName == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('chapters').update({'name': newName}).eq('id', chapter['id']);

      final list = novelChapters[novelId];
      if (list != null) {
        final idx = list.indexWhere((c) => c['id'] == chapter['id']);
        if (idx != -1) list[idx]['name'] = newName;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chapter name updated successfully")),
      );
    } catch (e) {
      debugPrint("Update chapter name error: $e");
    }
  }

  Future<void> editChapterContent(
      Map<String, dynamic> chapter, String novelId) async {
    final newContent = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          type: "Chapter Content",
          count: 1,
          initialContent: chapter['content'],
        ),
      ),
    );

    if (newContent == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('chapters').update({'content': newContent}).eq('id', chapter['id']);

      final list = novelChapters[novelId];
      if (list != null) {
        final idx = list.indexWhere((c) => c['id'] == chapter['id']);
        if (idx != -1) list[idx]['content'] = newContent;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chapter content updated successfully")),
      );
    } catch (e) {
      debugPrint("Update chapter content error: $e");
    }
  }

  // NEW: edit ebook content
  Future<void> editEbookContent(
      Map<String, dynamic> content, String ebookId) async {
    final newContent = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          type: "E-book Content",
          count: 1,
          initialContent: content['content'],
        ),
      ),
    );

    if (newContent == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('ebook_content')
          .update({'content': newContent})
          .eq('id', content['id']);

      final list = ebookContent[ebookId];
      if (list != null) {
        final idx = list.indexWhere((c) => c['id'] == content['id']);
        if (idx != -1) list[idx]['content'] = newContent;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-book content updated successfully")),
      );
    } catch (e) {
      debugPrint("Update ebook content error: $e");
    }
  }

  // NEW: Upload Ebook Content from File
  Future<void> uploadEbookContentFromFile(String ebookId, {String? contentId}) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileExtension = result.files.single.extension?.toLowerCase() ?? '';
        String fileContent = '';

        setState(() => isLoading = true);

        if (fileExtension == 'txt') {
           // LIMIT CHECK for TXT
           int sizeInBytes = await file.length();
           if (sizeInBytes > 10 * 1024 * 1024) { // 10MB limit
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("File is too large (Max 10MB)")),
            );
            setState(() => isLoading = false);
            return;
           }
           fileContent = await file.readAsString();
        } else if (fileExtension == 'docx') {
           // DOCX PARSING
           try {
             final bytes = await file.readAsBytes();
             
             // Run heavy parsing in an isolate to prevent UI freeze/crash
             fileContent = await compute(_parseDocxContent, bytes);
             
           } catch (e) {
             debugPrint("Error parsing docx: $e");
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Failed to parse .docx file: $e")),
             );
             setState(() => isLoading = false);
             return;
           }
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Unsupported file format")),
           );
           setState(() => isLoading = false);
           return;
        }


        if (fileContent.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("File is empty or no text found")),
          );
           setState(() => isLoading = false);
          return;
        }

        final supabase = Supabase.instance.client;
        
        if (contentId != null) {
           // Update existing
           await supabase
              .from('ebook_content')
              .update({'content': fileContent})
              .eq('id', contentId);
           
           // Update local list
           final list = ebookContent[ebookId];
           if (list != null) {
             final idx = list.indexWhere((c) => c['id'] == contentId);
             if (idx != -1) list[idx]['content'] = fileContent;
           }

        } else {
          // Insert new
           final inserted = await supabase
              .from('ebook_content')
              .insert({
                'ebook_id': ebookId,
                'content': fileContent,
              })
              .select()
              .single();
           
           if (ebookContent[ebookId] == null) {
             ebookContent[ebookId] = [];
           }
           ebookContent[ebookId]!.add(inserted);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Content uploaded successfully")),
        );
      } else {
        // User canceled the picker
      }
    } catch (e) {
      debugPrint("Error uploading file content: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload file: $e")),
      );
    } finally {
       setState(() => isLoading = false);
    }
  }


  Future<void> addScene(String parentId, bool isEbook) async {
    // Step 1: Pick an image
    final File? imageFile = await pickImage();
    if (imageFile == null) return; // user canceled

    // Step 2: Go to text editor
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





      // Determine which bucket to use
      final bucketName = isEbook ? 'ebooks' : 'novels';

// Build the path inside the bucket
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final path = '$parentId/Scenes/$fileName'; // parentId = novel ID or ebook ID

// Upload the file
      await supabase.storage.from(bucketName).upload(path, imageFile);

// Get the public URL
      final imageUrl = supabase.storage.from(bucketName).getPublicUrl(path);




      // Get max ord
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

      // Insert scene with text + image + ord
      await supabase.from(table).insert({
        'text': newText,
        'image_url': imageUrl,
        idField: parentId,
        'author_id': writerId,
        'ord': newOrd, // âœ… Correct Sequence
      });

      // Refresh all uploads and scenes
      await fetchUploads();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scene added successfully")),
      );
    } catch (e) {
      debugPrint("Add scene error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add scene")),
      );
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

      // 1. Get max ord
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

      // 2. Insert with ord
      final inserted = await supabase
          .from('chapters')
          .insert({
        'name': newName,
        'content': '',
        'novel_id': novelId,
        'author_id': writerId,
        'ord': newOrd, // âœ… Correct Sequence
      })
          .select()
          .single();

      novelChapters[novelId]?.add(inserted);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chapter added to end of list")),
      );
    } catch (e) {
      debugPrint("Add chapter error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding chapter: $e")),
      );
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
          selectedType == 'Novel' ? 'Edit Novel' : 'Edit E-book',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
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
                        title: Text(item['title'] ?? 'Untitled'),
                        trailing: IconButton(
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
                          // Novel Scenes
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Scenes", style: TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.blue),
                                      onPressed: () => addScene(id, false), // novel scene
                                    ),
                                  ],
                                ),
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
                                        ),
                                        onPressed: () => editScene(
                                            scene, id, false),
                                        child: const Text(
                                          "Edit",
                                          style: TextStyle(
                                              color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),

                          // Novel Chapters
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Chapters", style: TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.blue),
                                      onPressed: () => addChapter(id), // novel chapter
                                    ),
                                  ],
                                ),

                                ...?novelChapters[id]?.map((chapter) {
                                  final contentPreview =
                                      (chapter['content'] ?? '')
                                          .toString()
                                          .split('\n')
                                          .first;
                                  return Card(
                                    color: mainBlue,
                                    margin:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Padding(
                                      padding:
                                      const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  chapter['name'] ??
                                                      "Untitled Chapter",
                                                  style: const TextStyle(
                                                      color: Colors
                                                          .white,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold),
                                                ),
                                              ),
                                              TextButton(
                                                style: TextButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                  Colors.white,
                                                ),
                                                onPressed: () =>
                                                    editChapterName(
                                                        chapter,
                                                        id),
                                                child: const Text(
                                                  "Edit Name",
                                                  style: TextStyle(
                                                      color: Colors
                                                          .blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  contentPreview
                                                      .isEmpty
                                                      ? "No content"
                                                      : contentPreview,
                                                  style: const TextStyle(
                                                      color: Colors
                                                          .white70),
                                                ),
                                              ),
                                              TextButton(
                                                style: TextButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                  Colors.white,
                                                ),
                                                onPressed: () =>
                                                    editChapterContent(
                                                        chapter,
                                                        id),
                                                child: const Text(
                                                  "Edit Content",
                                                  style: TextStyle(
                                                      color: Colors.green),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ] else ...[
                          // E-book Scenes
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("E-book Scenes", style: TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.blue),
                                      onPressed: () => addScene(id, true), // ebook scene
                                    ),
                                  ],
                                ),
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
                                        ),
                                        onPressed: () => editScene(
                                            scene, id, true),
                                        child: const Text(
                                          "Edit",
                                          style: TextStyle(
                                              color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),

                          // E-book Content
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Text("E-book Content",
                                    style: TextStyle(
                                        fontWeight:
                                        FontWeight.bold)),
                                // NEW: Show Add Buttons if empty
                                if (ebookContent[id] == null || ebookContent[id]!.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => uploadEbookContentFromFile(id),
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text("Upload .txt / .docx"),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    ),
                                  ),

                                ...?ebookContent[id]?.map((content) {
                                  final contentPreview =
                                      (content['content'] ?? '')
                                          .toString()
                                          .split('\n')
                                          .first;
                                  return Card(
                                    color: mainBlue,
                                    margin:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Padding(
                                      padding:
                                      const EdgeInsets.all(12),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  contentPreview.isEmpty
                                                      ? "No content"
                                                      : contentPreview,
                                                  style: const TextStyle(
                                                      color:
                                                      Colors.white70),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Length: ${(content['content'] ?? '').length} chars",
                                                   style: const TextStyle(color: Colors.white30, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                               IconButton(
                                                icon: const Icon(Icons.upload_file, color: Colors.greenAccent),
                                                onPressed: () => uploadEbookContentFromFile(id, contentId: content['id']),
                                              ),
                                              TextButton(
                                                style: TextButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                  Colors.white,
                                                ),
                                                onPressed: () =>
                                                    editEbookContent(
                                                        content, id),
                                                child: const Text(
                                                  "Edit",
                                                  style: TextStyle(
                                                      color:
                                                      Colors.green),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ]
                      ],
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


// ---------------------------------------------------------------------------
// STANDALONE FUNCTION FOR ISOLATE (Must be top-level or static)
// ---------------------------------------------------------------------------
String _parseDocxContent(List<int> bytes) {
  try {
     final archive = ZipDecoder().decodeBytes(bytes);
             
     // Find document.xml
     final archiveFile = archive.findFile('word/document.xml');
     if (archiveFile == null) {
        throw Exception("Invalid .docx file (missing word/document.xml)");
     }

     // USE UTF-8 DECODING
     // Force cast to List<int> to be safe
     final content = utf8.decode(archiveFile.content as List<int>);
     final document = XmlDocument.parse(content);
     final texts = document.findAllElements('w:t');
     
     // Extract text and join
     String rawText = texts.map((node) => node.innerText).join('\n');
     return rawText;
  } catch (e) {
    throw Exception("Failed to parse docx in isolate: $e");
  }
}
