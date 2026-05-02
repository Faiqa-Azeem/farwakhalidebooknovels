class Scene {
  final String id;
  final String novelId;
  final String text;
  final String? imageUrl;
  final int order;
  final String? authorId;
  final DateTime? createdAt;

  Scene({
    required this.id,
    required this.novelId,
    required this.text,
    this.imageUrl,
    required this.order,
    this.authorId,
    this.createdAt,
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    final dynamic novelIdValue = json['novel_id'];
    final dynamic ordValue = json['ord'];
    final dynamic createdAtValue = json['created_at'];

    DateTime? createdAtParsed;
    if (createdAtValue is String) {
      createdAtParsed = DateTime.tryParse(createdAtValue);
    }

    return Scene(
      id: idValue?.toString() ?? '',
      novelId: novelIdValue?.toString() ?? '',
      text: (json['text'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      order: ordValue is num ? ordValue.toInt() : 0,
      authorId: json['author_id'] as String?,
      createdAt: createdAtParsed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'novel_id': novelId,
      'text': text,
      'image_url': imageUrl,
      'ord': order,
      'author_id': authorId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
