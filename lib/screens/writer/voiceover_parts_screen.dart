import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/supabase_service.dart';

class VoiceoverPartsScreen extends StatefulWidget {
  final String itemType;
  final String itemId;
  final String title;

  const VoiceoverPartsScreen({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.title,
  });

  @override
  State<VoiceoverPartsScreen> createState() => _VoiceoverPartsScreenState();
}

class _VoiceoverPartsScreenState extends State<VoiceoverPartsScreen> {
  final mainBlue = const Color(0xFF0D2144);
  List<Map<String, dynamic>> _parts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  Future<void> _loadParts() async {
    setState(() => _isLoading = true);
    final parts = await SupabaseService.getVoiceoversForItem(widget.itemType, widget.itemId);
    if (mounted) {
      setState(() {
        _parts = parts;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadNewPart() async {
    final nextPartNumber = _parts.isEmpty ? 1 : (_parts.last['part_number'] as int) + 1;
    
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      
      // Show upload dialog
      _showLoadingDialog("Uploading Part $nextPartNumber...");

      try {
        final audioUrl = await SupabaseService.uploadVoiceoverAudio(file, widget.itemType, widget.itemId);
        
        await SupabaseService.addVoiceoverRecord(
          itemType: widget.itemType,
          itemId: widget.itemId,
          partNumber: nextPartNumber,
          title: "Part $nextPartNumber",
          audioUrl: audioUrl,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Part $nextPartNumber added successfully!"), backgroundColor: Colors.green),
          );
          _loadParts(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deletePart(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Part"),
        content: const Text("Are you sure you want to delete this voiceover part?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    _showLoadingDialog("Deleting...");

    try {
      await SupabaseService.deleteVoiceover(id);
      await SupabaseService.resequenceVoiceovers(widget.itemType, widget.itemId);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deleted and resequenced successfully!"), backgroundColor: Colors.green),
        );
        _loadParts();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: mainBlue),
            const SizedBox(width: 20),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "${widget.title} - Voices",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: mainBlue))
          : _parts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text("No voiceovers added yet", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _parts.length,
                  itemBuilder: (context, index) {
                    final part = _parts[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mainBlue.withOpacity(0.1),
                          child: Icon(Icons.mic, color: mainBlue),
                        ),
                        title: Text(part['title'] ?? 'Part ${part['part_number']}', style: TextStyle(fontWeight: FontWeight.bold, color: mainBlue)),
                        subtitle: Text("Audio Track", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePart(part['id'].toString()),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadNewPart,
        backgroundColor: mainBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add New Part", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
