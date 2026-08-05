import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/supabase_service.dart';
import '../../utils/firebase_storage_service.dart'; // ✅ NEW: Firebase Storage
import 'text_editor_screen.dart';

class SceneItem {
  File? image; // mutable for editing
  String text;
  SceneItem({this.image, required this.text});
}

class ChapterItem {
  String content;
  ChapterItem({required this.content});
}

class UploadNovelScreen extends StatefulWidget {
  const UploadNovelScreen({Key? key}) : super(key: key);

  @override
  State<UploadNovelScreen> createState() => _UploadNovelScreenState();
}

class _UploadNovelScreenState extends State<UploadNovelScreen> {

  final supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _authorNameController = TextEditingController();
  bool _isUploading = false;
  String _status = 'Completed'; // Default status
  File? _coverImage;

  final ImagePicker _picker = ImagePicker();
  final List<SceneItem> _scenes = [];
  final List<ChapterItem> _chapters = [];

  // ---------- Pick Image ----------
  Future<File?> _pickImageFromGallery() async {
    final XFile? xfile =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return null;
    return File(xfile.path);
  }

  // ---------- Add Scene ----------
  Future<void> _addScene() async {
    File? pickedImage;
    String? sceneText;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          Future<void> pickImage() async {
            final f = await _pickImageFromGallery();
            setInnerState(() => pickedImage = f);
          }

          Future<void> writeText() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextEditorScreen(
                  type: "Scene",
                  count: _scenes.length + 1,
                ),
              ),
            );
            if (result != null && result is String) {
              setInnerState(() => sceneText = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Scene",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.photo),
                        label: const Text("Upload Picture"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: writeText,
                        icon: const Icon(Icons.edit),
                        label: const Text("Write Scene"),
                      ),
                    ),
                  ],
                ),
                if (pickedImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.file(pickedImage!,
                        height: 120, fit: BoxFit.cover),
                  ),
                if (sceneText != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sceneText!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel")),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (sceneText == null || sceneText!.trim().isEmpty) {
                            setInnerState(
                                    () => errorMsg = "⚠️ Please write scene text");
                            return;
                          }
                          setState(() => _scenes.add(SceneItem(
                              image: pickedImage, text: sceneText!.trim())));
                          Navigator.pop(context);
                        },
                        child: const Text("Save Scene"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------- Edit Scene ----------
  Future<void> _editScene(int index) async {
    final scene = _scenes[index];
    File? pickedImage = scene.image;
    String sceneText = scene.text;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          Future<void> pickImage() async {
            final f = await _pickImageFromGallery();
            if (f != null) setInnerState(() => pickedImage = f);
          }

          Future<void> writeText() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextEditorScreen(
                  type: "Scene",
                  count: index + 1,
                  initialContent: sceneText,
                ),
              ),
            );
            if (result != null && result is String) {
              setInnerState(() => sceneText = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Scene",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.photo),
                        label: const Text("Change Picture"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: writeText,
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit Text"),
                      ),
                    ),
                  ],
                ),
                if (pickedImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.file(pickedImage!,
                        height: 120, fit: BoxFit.cover),
                  ),
                if (sceneText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sceneText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel")),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          if (sceneText.trim().isEmpty) {
                            setInnerState(
                                    () => errorMsg = "⚠️ Please write scene text");
                            return;
                          }
                          setState(() {
                            scene.image = pickedImage;
                            scene.text = sceneText.trim();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Update Scene",
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------- Add Chapter ----------
  Future<void> _addChapter() async {
    String? chapterContent;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          Future<void> writeContent() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextEditorScreen(
                  type: "Chapter",
                  count: _chapters.length + 1,
                ),
              ),
            );
            if (result != null && result is String) {
              setInnerState(() => chapterContent = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Chapter",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: writeContent,
                  icon: const Icon(Icons.edit),
                  label: const Text("Write Chapter"),
                ),
                if (chapterContent != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      chapterContent!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          if (chapterContent == null ||
                              chapterContent!.trim().isEmpty) {
                            setInnerState(() => errorMsg =
                            "⚠️ Please write chapter content");
                            return;
                          }
                          setState(() => _chapters.add(ChapterItem(
                              content: chapterContent!.trim())));
                          Navigator.pop(context);
                        },
                        child: const Text("Save Chapter",
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------- Edit Chapter ----------
  Future<void> _editChapter(int index) async {
    final chapter = _chapters[index];
    String chapterContent = chapter.content;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          Future<void> writeContent() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextEditorScreen(
                  type: "Chapter",
                  count: index + 1,
                  initialContent: chapterContent,
                ),
              ),
            );
            if (result != null && result is String) {
              setInnerState(() => chapterContent = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Chapter",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: writeContent,
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Content"),
                ),
                if (chapterContent.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      chapterContent,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          if (chapterContent.trim().isEmpty) {
                            setInnerState(() => errorMsg =
                            "⚠️ Please write chapter content");
                            return;
                          }
                          setState(() {
                            chapter.content = chapterContent.trim();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Update Chapter",
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------- Upload Novel ----------
  Future<void> _uploadNovel() async {
    final title = _titleController.text.trim();
    final authorName = _authorNameController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter novel title")));
      return;
    }

    if (authorName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter author name")));
      return;
    }

    if (_scenes.isEmpty && _chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add at least one scene or chapter")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2';

      // 1️⃣ Insert novel first (without cover)
      final novel = await supabase.from('novels').insert({
        'title': title,
        'author_name': authorName,
        'author_id': writerId,
        'status': _status,
      }).select().single();

      final novelId = novel['id'] as String?;
      if (novelId == null) throw Exception("Failed to create novel");

      // 2️⃣ Upload cover if selected
      String? coverUrl;
      if (_coverImage != null) {
        final coverPath =
            'novels/$novelId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        coverUrl = await FirebaseStorageService.uploadFile(_coverImage!, coverPath);
        if (coverUrl != null) {
          await supabase.from('novels').update({
            'cover_url': coverUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', novelId);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novel created, but cover upload failed. Edit the novel to re-upload the cover.'),
            ),
          );
        }
      }

      // 3️⃣ Upload scenes
      for (var i = 0; i < _scenes.length; i++) {
        final s = _scenes[i];
        String? publicUrl;
        if (s.image != null) {
          final path = 'novels/$novelId/scenes/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          publicUrl = await FirebaseStorageService.uploadFile(s.image!, path);
        }
        await supabase.from('scenes').insert({
          'novel_id': novelId,
          'text': s.text,
          'image_url': publicUrl,
          'ord': i,
          'author_id': writerId,
        });
      }

      // 4️⃣ Upload chapters with default name
      for (var i = 0; i < _chapters.length; i++) {
        final c = _chapters[i];
        await supabase.from('chapters').insert({
          'novel_id': novelId,
          'name': 'Chapter ${i + 1}',  // Added default name here
          'content': c.content,
          'ord': i,
          'author_id': writerId,
        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Novel uploaded successfully")));

      await SupabaseService.clearSessionCache(); // Force refresh of lists

      setState(() {
        _titleController.clear();
        _authorNameController.clear();
        _scenes.clear();
        _chapters.clear();
        _coverImage = null;
      });
    } catch (e) {
      debugPrint("Upload error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }


  // ---------- Build UI ----------
  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF0D2144);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Novel"),
        backgroundColor: mainBlue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: "Novel Title",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _authorNameController,
                  decoration: InputDecoration(
                    labelText: "Author Name",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: "Status",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                  ],
                  onChanged: (val) => setState(() => _status = val!),
                ),
                const SizedBox(height: 16),
                Text("Novel Cover", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickImageFromGallery();
                    if (picked != null) setState(() => _coverImage = picked);
                  },
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: _coverImage != null
                        ? Image.file(
                            _coverImage!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : const Center(child: Text("Tap to upload cover")),
                  ),
                ),
                const SizedBox(height: 20),

                // Scenes Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Scenes",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                        onPressed: _addScene,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text("Add Scene")),
                  ],
                ),
                ..._scenes.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: s.image != null
                          ? SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.file(s.image!, fit: BoxFit.cover))
                          : null,
                      title: Text("Scene ${idx + 1}"),
                      subtitle: Text(
                        s.text.split(" ").take(4).join(" "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editScene(idx)),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _scenes.removeAt(idx))),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 20),
                // Chapters Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Chapters",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                        onPressed: _addChapter,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Chapter")),
                  ],
                ),
                ..._chapters.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text("Chapter ${idx + 1}"),
                      subtitle: Text(
                        c.content.split(" ").take(5).join(" "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editChapter(idx)),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _chapters.removeAt(idx))),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),
                _isUploading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  onPressed: _uploadNovel,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Upload Novel",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}