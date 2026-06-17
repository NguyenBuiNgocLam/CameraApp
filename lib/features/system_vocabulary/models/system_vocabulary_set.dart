import 'package:cloud_firestore/cloud_firestore.dart';

class SystemVocabularySet {
  const SystemVocabularySet({
    required this.id,
    required this.name,
    required this.description,
    required this.totalWords,
    required this.sourceStyle,
    required this.sourceUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int totalWords;
  final String sourceStyle;
  final String sourceUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemVocabularySet copyWith({
    String? id,
    String? name,
    String? description,
    int? totalWords,
    String? sourceStyle,
    String? sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SystemVocabularySet(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      totalWords: totalWords ?? this.totalWords,
      sourceStyle: sourceStyle ?? this.sourceStyle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SystemVocabularySet.fromJson(Map<String, dynamic> json) {
    return SystemVocabularySet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      totalWords: (json['totalWords'] as num?)?.toInt() ?? 0,
      sourceStyle: json['sourceStyle'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory SystemVocabularySet.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SystemVocabularySet.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'totalWords': totalWords,
      'sourceStyle': sourceStyle,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
