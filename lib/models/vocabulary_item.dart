import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VocabularyDefinition {
  const VocabularyDefinition({
    required this.partOfSpeech,
    required this.meaningVi,
  });

  final String partOfSpeech;
  final String meaningVi;

  VocabularyDefinition copyWith({String? partOfSpeech, String? meaningVi}) {
    return VocabularyDefinition(
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      meaningVi: meaningVi ?? this.meaningVi,
    );
  }

  factory VocabularyDefinition.fromJson(Map<String, dynamic> json) {
    return VocabularyDefinition(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      meaningVi:
          json['meaningVi'] as String? ?? json['meaning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'partOfSpeech': partOfSpeech, 'meaningVi': meaningVi};
  }
}

class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.userId,
    required this.word,
    required this.meaningVi,
    required this.phonetic,
    required this.partOfSpeech,
    required this.exampleEn,
    required this.exampleVi,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.imageUrl,
    this.isFavorite = false,
    this.listId = 'default',
    this.sourceContext = '',
    this.definitions = const [],
    this.learningLevel = 'unknown',
    this.correctCount = 0,
    this.wrongCount = 0,
    this.hasSeenFlashcard = false,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.confidence,
    this.icon = Icons.menu_book_rounded,
  });

  final String id;
  final String userId;
  final String word;
  final String meaningVi;
  final String phonetic;
  final String partOfSpeech;
  final String exampleEn;
  final String exampleVi;
  final String? imagePath;
  final String? imageUrl;
  final bool isFavorite;
  final String listId;
  final String sourceContext;
  final List<VocabularyDefinition> definitions;
  final String learningLevel;
  final int correctCount;
  final int wrongCount;
  final bool hasSeenFlashcard;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final double? confidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final IconData icon;

  String get meaning => meaningVi;
  String get example => exampleEn;
  String get translation => exampleVi;
  List<VocabularyDefinition> get effectiveDefinitions {
    if (definitions.isNotEmpty) return definitions;
    if (meaningVi.trim().isEmpty && partOfSpeech.trim().isEmpty) {
      return const [];
    }
    return [
      VocabularyDefinition(partOfSpeech: partOfSpeech, meaningVi: meaningVi),
    ];
  }

  VocabularyItem copyWith({
    String? id,
    String? userId,
    String? word,
    String? meaningVi,
    String? phonetic,
    String? partOfSpeech,
    String? exampleEn,
    String? exampleVi,
    String? imagePath,
    String? imageUrl,
    bool? isFavorite,
    String? listId,
    String? sourceContext,
    List<VocabularyDefinition>? definitions,
    String? learningLevel,
    int? correctCount,
    int? wrongCount,
    bool? hasSeenFlashcard,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    IconData? icon,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      word: word ?? this.word,
      meaningVi: meaningVi ?? this.meaningVi,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      exampleEn: exampleEn ?? this.exampleEn,
      exampleVi: exampleVi ?? this.exampleVi,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      listId: listId ?? this.listId,
      sourceContext: sourceContext ?? this.sourceContext,
      definitions: definitions ?? this.definitions,
      learningLevel: learningLevel ?? this.learningLevel,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      hasSeenFlashcard: hasSeenFlashcard ?? this.hasSeenFlashcard,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      icon: icon ?? this.icon,
    );
  }

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      word: json['word'] as String? ?? '',
      meaningVi:
          json['meaningVi'] as String? ?? json['meaning'] as String? ?? '',
      phonetic: json['phonetic'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      exampleEn:
          json['exampleEn'] as String? ?? json['example'] as String? ?? '',
      exampleVi:
          json['exampleVi'] as String? ?? json['translation'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      listId: json['listId'] as String? ?? 'default',
      sourceContext: json['sourceContext'] as String? ?? '',
      definitions: _readDefinitions(json['definitions']),
      learningLevel: json['learningLevel'] as String? ?? 'unknown',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      hasSeenFlashcard: json['hasSeenFlashcard'] as bool? ?? false,
      lastReviewedAt: _readNullableDate(json['lastReviewedAt']),
      nextReviewAt: _readNullableDate(json['nextReviewAt']),
      confidence: (json['confidence'] as num?)?.toDouble(),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      icon: _iconFromName(json['iconName'] as String?),
    );
  }

  factory VocabularyItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VocabularyItem.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'word': word,
      'meaningVi': meaningVi,
      'phonetic': phonetic,
      'partOfSpeech': partOfSpeech,
      'exampleEn': exampleEn,
      'exampleVi': exampleVi,
      'imagePath': imagePath,
      'imageUrl': imageUrl ?? '',
      'isFavorite': isFavorite,
      'listId': listId,
      'sourceContext': sourceContext,
      'definitions':
          definitions.map((definition) => definition.toJson()).toList(),
      'learningLevel': learningLevel,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'hasSeenFlashcard': hasSeenFlashcard,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'confidence': confidence,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'iconName': _iconName(icon),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'word': word,
      'meaningVi': meaningVi,
      'phonetic': phonetic,
      'partOfSpeech': partOfSpeech,
      'exampleEn': exampleEn,
      'exampleVi': exampleVi,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'listId': listId,
      'sourceContext': sourceContext,
      'definitions':
          definitions.map((definition) => definition.toJson()).toList(),
      'learningLevel': learningLevel,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'hasSeenFlashcard': hasSeenFlashcard,
      'lastReviewedAt':
          lastReviewedAt == null ? null : Timestamp.fromDate(lastReviewedAt!),
      'nextReviewAt':
          nextReviewAt == null ? null : Timestamp.fromDate(nextReviewAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static List<VocabularyDefinition> _readDefinitions(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((definition) {
          return VocabularyDefinition.fromJson(
            definition.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .where(
          (definition) =>
              definition.partOfSpeech.trim().isNotEmpty ||
              definition.meaningVi.trim().isNotEmpty,
        )
        .toList();
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

  static IconData _iconFromName(String? name) {
    return switch (name) {
      'camera' => Icons.photo_camera_rounded,
      'bottle' => Icons.water_drop_rounded,
      'laptop' => Icons.laptop_mac_rounded,
      'backpack' => Icons.backpack_rounded,
      'headphones' => Icons.headphones_rounded,
      _ => Icons.menu_book_rounded,
    };
  }

  static String _iconName(IconData icon) {
    if (icon == Icons.photo_camera_rounded) return 'camera';
    if (icon == Icons.water_drop_rounded) return 'bottle';
    if (icon == Icons.laptop_mac_rounded) return 'laptop';
    if (icon == Icons.backpack_rounded) return 'backpack';
    if (icon == Icons.headphones_rounded) return 'headphones';
    return 'word';
  }
}
