class Novel {
  final String id;
  final String title;
  final String? coverUrl;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  Novel({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'Completed',
  });

  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      authorId: json['author_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: json['status'] as String? ?? 'Completed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'author_id': authorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status,
    };
  }
}
