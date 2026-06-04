import 'package:cloud_firestore/cloud_firestore.dart';

class WordList {
  const WordList({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  WordList copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WordList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WordList.fromJson(Map<String, dynamic> json) {
    return WordList(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory WordList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return WordList.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'wordCount': wordCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'wordCount': wordCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
