import 'package:cloud_firestore/cloud_firestore.dart';

class Permission {
  final String id;
  final String content;
  final bool isCompleted;
  final int reflectionScore; // 0=未記入, 1〜5
  final String reflectionText;
  final DateTime date;

  const Permission({
    required this.id,
    required this.content,
    required this.isCompleted,
    required this.reflectionScore,
    required this.reflectionText,
    required this.date,
  });

  factory Permission.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const {};
    return Permission(
      id: doc.id,
      content: map['content'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      reflectionScore: (map['reflectionScore'] as num?)?.toInt() ?? 0,
      reflectionText: map['reflectionText'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'isCompleted': isCompleted,
      'reflectionScore': reflectionScore,
      'reflectionText': reflectionText,
      'date': Timestamp.fromDate(date),
    };
  }

  Permission copyWith({
    String? content,
    bool? isCompleted,
    int? reflectionScore,
    String? reflectionText,
    DateTime? date,
  }) {
    return Permission(
      id: id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      reflectionScore: reflectionScore ?? this.reflectionScore,
      reflectionText: reflectionText ?? this.reflectionText,
      date: date ?? this.date,
    );
  }
}
