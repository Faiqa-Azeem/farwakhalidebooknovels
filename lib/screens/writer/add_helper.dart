
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

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
