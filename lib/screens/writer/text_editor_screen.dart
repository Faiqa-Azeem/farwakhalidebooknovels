import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class TextEditorScreen extends StatefulWidget {
  final String type; // Scene or Chapter
  final int count;   // Scene 1, Chapter 2, etc.
  final String? initialContent; // Optional, for editing existing content

  const TextEditorScreen({
    Key? key,
    required this.type,
    required this.count,
    this.initialContent,
  }) : super(key: key);

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();

    Document doc;
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      doc = Document()..insert(0, widget.initialContent!);
    } else {
      doc = Document();
    }
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _saveContent() {
    final plainText = _controller.document.toPlainText();
    Navigator.pop(context, plainText); // Send back to UploadNovelScreen
  }

  @override
  Widget build(BuildContext context) {
    const Color mainBlue = Color(0xFF0D2144);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: mainBlue,
        title: Text(
          "Write ${widget.type} ${widget.count}",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveContent,
          ),
        ],
      ),
      body: Column(
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showFontFamily: true,
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showColorButton: true,
            ),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: _controller,
              config: const QuillEditorConfig(
                autoFocus: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
