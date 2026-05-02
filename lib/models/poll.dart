import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({required this.id, required this.text, required this.votes});

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      votes: map['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
    };
  }
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final List<String> voters;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.createdAt,
    this.voters = const [],
  });

  factory Poll.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception("Poll document does not exist");
    }
    final data = doc.data() as Map<String, dynamic>;
    return Poll(
      id: doc.id,
      question: data['question'] ?? '',
      options: (data['options'] as List<dynamic>?)
              ?.map((e) => PollOption.fromMap(e))
              .toList() ??
          [],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      voters: List<String>.from(data['voters'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options.map((e) => e.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
      'voters': voters,
    };
  }
}
