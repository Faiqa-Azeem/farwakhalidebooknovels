import 'package:hive/hive.dart';

part 'ebook.g.dart'; // Needed for Hive type adapter

// ==========================
// Online Ebook model (Supabase)
// ==========================
class Ebook {
  final String id;
  final String title;
  final String? coverUrl;
  final String authorId;
  final String? fileUrl; // <-- Add fileUrl for actual ebook (pdf/epub)
  final String status;
  final int? price; // <-- Added price for bundle logic

  Ebook({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.authorId,
    this.fileUrl,
    this.status = 'Completed',
    this.price,
  });

  factory Ebook.fromJson(Map<String, dynamic> json) {
    return Ebook(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      authorId: json['author_id'] as String,
      fileUrl: json['file_url'] as String?, // make sure you have this column in Supabase
      status: json['status'] as String? ?? 'Completed',
      price: json['price'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'author_id': authorId,
      'file_url': fileUrl,
      'status': status,
      'price': price,
    };
  }
}

// ==========================
// Offline Ebook model (Hive)
// ==========================
@HiveType(typeId: 0)
class LocalEbook extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? coverUrl;

  @HiveField(3)
  String authorId;

  @HiveField(4)
  String localFilePath; // <-- Path of saved file in device

  @HiveField(5)
  int? price;

  LocalEbook({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.authorId,
    required this.localFilePath,
    this.price,
  });
}
