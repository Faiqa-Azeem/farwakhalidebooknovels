class AppNotification {
  final String id;
  final String text;
  final String authorId;
  final DateTime createdAt;
  final bool isPinned;

  AppNotification({
    required this.id,
    required this.text,
    required this.authorId,
    required this.createdAt,
    this.isPinned = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      text: json['text'] ?? '',
      authorId: json['author_id'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isPinned: json['pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'author_id': authorId,
      'created_at': createdAt.toIso8601String(),
      'pinned': isPinned,
    };
  }

  // Extracts Poll ID if present in format ||POLL_ID:xyz||
  String? get pollId {
    final regex = RegExp(r'\|\|POLL_ID:(.+?)\|\|');
    final match = regex.firstMatch(text);
    return match?.group(1);
  }

  // Returns text without the Poll ID tag
  String get cleanText {
    final regex = RegExp(r'\|\|POLL_ID:(.+?)\|\|');
    return text.replaceAll(regex, '').trim();
  }
}
