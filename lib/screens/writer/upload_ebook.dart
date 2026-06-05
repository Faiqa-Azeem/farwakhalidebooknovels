import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/supabase_service.dart';
import 'text_editor_screen.dart';

class SceneItem {
  final File? image;
  final String text;
  SceneItem({this.image, required this.text});
}

class UploadEbookScreen extends StatefulWidget {
  const UploadEbookScreen({Key? key}) : super(key: key);

  @override
  State<UploadEbookScreen> createState() => _UploadEbookScreenState();
}

class _UploadEbookScreenState extends State<UploadEbookScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController(); // ✅ Added Controller
  bool _isUploading = false;
  String _status = 'Completed'; // Default status

  final ImagePicker _picker = ImagePicker();
  final List<SceneItem> _scenes = [];
  String? _ebookContent;
  File? _coverImage; // <-- NEW: Cover image

  // ---------- Pick Image ----------
  Future<File?> _pickImageFromGallery() async {
    final XFile? xfile =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return null;
    return File(xfile.path);
  }

  // ---------- Pick Cover ----------
  Future<void> _pickCover() async {
    final f = await _pickImageFromGallery();
    if (f != null) setState(() => _coverImage = f);
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
  Future<SceneItem?> _editScene(SceneItem scene) async {
    File? pickedImage = scene.image;
    String? sceneText = scene.text;
    String? errorMsg;

    return await showModalBottomSheet<SceneItem>(
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
                  count: _scenes.indexOf(scene) + 1,
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
                          Navigator.pop(
                              context,
                              SceneItem(
                                  image: pickedImage, text: sceneText!.trim()));
                        },
                        child: const Text("Update Scene"),
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

  // ---------- Add Ebook Content ----------
  Future<void> _addEbookContent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(type: "Ebook", count: 1),
      ),
    );
    if (result != null && result is String) {
      setState(() => _ebookContent = result);
    }
  }

  // ---------- Upload to Supabase ----------
  Future<void> _uploadEbook() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter ebook title")));
      return;
    }
    if (_scenes.isEmpty && (_ebookContent == null || _ebookContent!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add scenes or ebook content")));
      return;
    }

    setState(() => _isUploading = true);

    final priceStr = _priceController.text.trim();
    if (priceStr.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter eBook price")));
       setState(() => _isUploading = false);
       return;
    }

    final price = int.tryParse(priceStr);
    if (price == null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid price format")));
       setState(() => _isUploading = false);
       return;
    }

    try {
      final supabase = Supabase.instance.client;
      const writerId = 'DFm3K8mo4QPM4pqjVU3VDm1po9q2';

      // Insert ebook
      final ebook = await supabase.from('ebooks').insert({
        'title': title,
        'author_id': writerId,
        'price': price, // ✅ Insert PRICE
        'status': _status,
      }).select().single();

      final ebookId = ebook['id'] as String?;
      if (ebookId == null) throw Exception("Failed to create ebook");

      // Upload cover if selected
      String? coverUrl;
      if (_coverImage != null) {
        final path = '$ebookId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('ebooks').upload(path, _coverImage!);
        coverUrl = supabase.storage.from('ebooks').getPublicUrl(path);
        
        await supabase
            .from('ebooks')
            .update({'cover_url': coverUrl})
            .eq('id', ebookId);
      }

      // Upload scenes
      for (var i = 0; i < _scenes.length; i++) {
        final s = _scenes[i];
        String? publicUrl;
        if (s.image != null) {
          final path = '$ebookId/scenes/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await supabase.storage.from('ebooks').upload(path, s.image!);
          publicUrl = supabase.storage.from('ebooks').getPublicUrl(path);
        }
        await supabase.from('ebook_scenes').insert({
          'ebook_id': ebookId,
          'text': s.text,
          'image_url': publicUrl,
          'ord': i,
          'author_id': writerId,
        });
      }

      // Upload content (only one)
      if (_ebookContent != null && _ebookContent!.isNotEmpty) {
        await supabase.from('ebook_content').insert({
          'ebook_id': ebookId,
          'content': _ebookContent!,
          'author_id': writerId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ebook uploaded successfully")));
      
      SupabaseService.clearSessionCache(); // Force refresh of lists
      
      setState(() {
        _titleController.clear();
        _scenes.clear();
        _ebookContent = null;
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
        title: const Text("Upload Ebook"),
        backgroundColor: mainBlue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Ebook Title",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Price (PKR)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
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
            const SizedBox(height: 20),

            // ---------- Cover Picker ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ebook Cover",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                    onPressed: _pickCover,
                    icon: const Icon(Icons.photo),
                    label: const Text("Upload Cover")),
              ],
            ),
            if (_coverImage != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 160,
                child: Image.file(_coverImage!, fit: BoxFit.cover),
              ),

            // Scenes Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Scenes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        onPressed: () async {
                          final editedScene = await _editScene(s);
                          if (editedScene != null) {
                            setState(() => _scenes[idx] = editedScene);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _scenes.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),

            // Ebook Content
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ebook Content",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                    onPressed: _addEbookContent,
                    icon: const Icon(Icons.edit),
                    label: const Text("Write Ebook")),
              ],
            ),
            if (_ebookContent != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _ebookContent!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TextEditorScreen(
                              type: "Ebook",
                              count: 1,
                              initialContent: _ebookContent,
                            ),
                          ),
                        );
                        if (result != null && result is String) {
                          setState(() => _ebookContent = result);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _ebookContent = null),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _uploadEbook,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Upload Ebook",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
