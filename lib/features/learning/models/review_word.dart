import 'learning_word.dart';

class ReviewWord {
  const ReviewWord({
    required this.id,
    required this.sourceType,
    required this.word,
    required this.meaningVi,
    required this.learningLevel,
    required this.correctCount,
    required this.wrongCount,
    required this.hasSeenFlashcard,
    this.setId,
    this.wordId,
    this.progressId,
    this.vocabularyId,
    this.listId,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.exampleEn = '',
    this.exampleVi = '',
    this.topic = '',
    this.nextReviewAt,
    this.lastReviewedAt,
  });

  final String id;
  final LearningSourceType sourceType;
  final String? setId;
  final String? wordId;
  final String? progressId;
  final String? vocabularyId;
  final String? listId;
  final String word;
  final String meaningVi;
  final String phonetic;
  final String partOfSpeech;
  final String exampleEn;
  final String exampleVi;
  final String topic;
  final String learningLevel;
  final int correctCount;
  final int wrongCount;
  final bool hasSeenFlashcard;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;

  LearningWord toLearningWord() {
    return LearningWord(
      id: id,
      sourceType: sourceType,
      setId: setId,
      listId: listId,
      word: word,
      meaningVi: meaningVi,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      exampleEn: exampleEn,
      exampleVi: exampleVi,
      topic: topic,
      learningLevel: learningLevel,
      correctCount: correctCount,
      wrongCount: wrongCount,
      hasSeenFlashcard: hasSeenFlashcard,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: nextReviewAt,
      isFavorite: false,
    );
  }
}
