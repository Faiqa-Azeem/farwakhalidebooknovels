import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file to Firebase Storage and returns the public download URL.
  /// [path] should be the destination path in the bucket (e.g., 'ebooks/123/cover.jpg')
  static Future<String?> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      
      // Upload the file
      final uploadTask = ref.putFile(
        file, 
        SettableMetadata(
          contentType: _getContentType(path),
        )
      );

      // Wait for completion
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
      
    } catch (e) {
      debugPrint("Firebase Storage Upload Error: $e");
      return null;
    }
  }

  /// Helper to guess content type based on file extension
  static String _getContentType(String path) {
    if (path.toLowerCase().endsWith('.jpg') || path.toLowerCase().endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (path.toLowerCase().endsWith('.png')) {
      return 'image/png';
    } else if (path.toLowerCase().endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'application/octet-stream';
  }
}
