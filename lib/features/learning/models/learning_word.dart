import '../../../models/vocabulary_item.dart';
import '../../system_vocabulary/models/system_vocabulary_item.dart';
import '../../system_vocabulary/models/system_vocabulary_progress.dart';

enum LearningSourceType { system, userVocabulary }

enum LearningSessionMode { learn, review }

class LearningWord {
  const LearningWord({
    required this.id,
    required this.sourceType,
    required this.word,
    required this.meaningVi,
    required this.learningLevel,
    required this.correctCount,
    required this.wrongCount,
    required this.hasSeenFlashcard,
    required this.isFavorite,
    this.setId,
    this.listId,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.exampleEn = '',
    this.exampleVi = '',
    this.topic = '',
    this.definitions = const [],
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final String id;
  final LearningSourceType sourceType;
  final String? setId;
  final String? listId;
  final String word;
  final String meaningVi;
  final String phonetic;
  final String partOfSpeech;
  final String exampleEn;
  final String exampleVi;
  final String topic;
  final List<VocabularyDefinition> definitions;
  final String learningLevel;
  final int correctCount;
  final int wrongCount;
  final bool hasSeenFlashcard;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final bool isFavorite;

  factory LearningWord.fromSystemVocabularyItem(
    SystemVocabularyItem item, {
    SystemVocabularyProgress? progress,
  }) {
    return LearningWord(
      id: item.id,
      sourceType: LearningSourceType.system,
      setId: item.setId,
      word: item.word,
      meaningVi: item.meaningVi,
      partOfSpeech: item.partOfSpeech,
      topic: item.topic,
      learningLevel: progress?.learningLevel ?? 'unknown',
      correctCount: progress?.correctCount ?? 0,
      wrongCount: progress?.wrongCount ?? 0,
      hasSeenFlashcard: progress?.hasSeenFlashcard ?? false,
      lastReviewedAt: progress?.lastReviewedAt,
      nextReviewAt: progress?.nextReviewAt,
      isFavorite: progress?.isFavorite ?? false,
    );
  }

  factory LearningWord.fromUserVocabularyItem(VocabularyItem item) {
    return LearningWord(
      id: item.id,
      sourceType: LearningSourceType.userVocabulary,
      listId: item.listId,
      word: item.word,
      meaningVi: item.meaningVi,
      phonetic: item.phonetic,
      partOfSpeech: item.partOfSpeech,
      exampleEn: item.exampleEn,
      exampleVi: item.exampleVi,
      topic: item.sourceContext,
      definitions: item.effectiveDefinitions,
      learningLevel: item.learningLevel,
      correctCount: item.correctCount,
      wrongCount: item.wrongCount,
      hasSeenFlashcard: item.hasSeenFlashcard,
      lastReviewedAt: item.lastReviewedAt,
      nextReviewAt: item.nextReviewAt,
      isFavorite: item.isFavorite,
    );
  }

  LearningWord copyWith({
    String? id,
    LearningSourceType? sourceType,
    String? setId,
    String? listId,
    String? word,
    String? meaningVi,
    String? phonetic,
    String? partOfSpeech,
    String? exampleEn,
    String? exampleVi,
    String? topic,
    List<VocabularyDefinition>? definitions,
    String? learningLevel,
    int? correctCount,
    int? wrongCount,
    bool? hasSeenFlashcard,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool? isFavorite,
  }) {
    return LearningWord(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      setId: setId ?? this.setId,
      listId: listId ?? this.listId,
      word: word ?? this.word,
      meaningVi: meaningVi ?? this.meaningVi,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      exampleEn: exampleEn ?? this.exampleEn,
      exampleVi: exampleVi ?? this.exampleVi,
      topic: topic ?? this.topic,
      definitions: definitions ?? this.definitions,
      learningLevel: learningLevel ?? this.learningLevel,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      hasSeenFlashcard: hasSeenFlashcard ?? this.hasSeenFlashcard,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
