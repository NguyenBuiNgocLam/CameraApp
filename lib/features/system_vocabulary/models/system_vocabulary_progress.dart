import 'package:cloud_firestore/cloud_firestore.dart';

class SystemVocabularyProgress {
  const SystemVocabularyProgress({
    required this.id,
    required this.userId,
    required this.setId,
    required this.wordId,
    required this.learningLevel,
    required this.correctCount,
    required this.wrongCount,
    required this.hasSeenFlashcard,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final String id;
  final String userId;
  final String setId;
  final String wordId;
  final String learningLevel;
  final int correctCount;
  final int wrongCount;
  final bool hasSeenFlashcard;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemVocabularyProgress copyWith({
    String? id,
    String? userId,
    String? setId,
    String? wordId,
    String? learningLevel,
    int? correctCount,
    int? wrongCount,
    bool? hasSeenFlashcard,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SystemVocabularyProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      setId: setId ?? this.setId,
      wordId: wordId ?? this.wordId,
      learningLevel: learningLevel ?? this.learningLevel,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      hasSeenFlashcard: hasSeenFlashcard ?? this.hasSeenFlashcard,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SystemVocabularyProgress.fromJson(Map<String, dynamic> json) {
    return SystemVocabularyProgress(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      setId: json['setId'] as String? ?? '',
      wordId: json['wordId'] as String? ?? '',
      learningLevel: json['learningLevel'] as String? ?? 'unknown',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      hasSeenFlashcard: json['hasSeenFlashcard'] as bool? ?? false,
      lastReviewedAt: _readNullableDate(json['lastReviewedAt']),
      nextReviewAt: _readNullableDate(json['nextReviewAt']),
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory SystemVocabularyProgress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SystemVocabularyProgress.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'setId': setId,
      'wordId': wordId,
      'learningLevel': learningLevel,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'hasSeenFlashcard': hasSeenFlashcard,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'setId': setId,
      'wordId': wordId,
      'learningLevel': learningLevel,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'hasSeenFlashcard': hasSeenFlashcard,
      'lastReviewedAt':
          lastReviewedAt == null ? null : Timestamp.fromDate(lastReviewedAt!),
      'nextReviewAt':
          nextReviewAt == null ? null : Timestamp.fromDate(nextReviewAt!),
      'isFavorite': isFavorite,
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

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
