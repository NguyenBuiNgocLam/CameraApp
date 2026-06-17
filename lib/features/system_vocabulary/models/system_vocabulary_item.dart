import 'package:cloud_firestore/cloud_firestore.dart';

class SystemVocabularyItem {
  const SystemVocabularyItem({
    required this.id,
    required this.setId,
    required this.no,
    required this.topic,
    required this.word,
    required this.meaningVi,
    required this.partOfSpeech,
    required this.sourceStyle,
    required this.sourceUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String setId;
  final int no;
  final String topic;
  final String word;
  final String meaningVi;
  final String partOfSpeech;
  final String sourceStyle;
  final String sourceUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemVocabularyItem copyWith({
    String? id,
    String? setId,
    int? no,
    String? topic,
    String? word,
    String? meaningVi,
    String? partOfSpeech,
    String? sourceStyle,
    String? sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SystemVocabularyItem(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      no: no ?? this.no,
      topic: topic ?? this.topic,
      word: word ?? this.word,
      meaningVi: meaningVi ?? this.meaningVi,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      sourceStyle: sourceStyle ?? this.sourceStyle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SystemVocabularyItem.fromJson(Map<String, dynamic> json) {
    return SystemVocabularyItem(
      id: json['id'] as String? ?? '',
      setId: json['setId'] as String? ?? '',
      no: (json['no'] as num?)?.toInt() ?? 0,
      topic: json['topic'] as String? ?? '',
      word: json['word'] as String? ?? '',
      meaningVi: json['meaningVi'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      sourceStyle: json['sourceStyle'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory SystemVocabularyItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SystemVocabularyItem.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setId': setId,
      'no': no,
      'topic': topic,
      'word': word,
      'meaningVi': meaningVi,
      'partOfSpeech': partOfSpeech,
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
