import '../../../models/vocabulary_item.dart';

enum LearningQuestionType { flashcard, inputWord, chooseMeaning, trueFalse }

class LearningQuestion {
  const LearningQuestion({
    required this.id,
    required this.type,
    required this.vocabularyItem,
    required this.questionText,
    required this.correctAnswer,
    required this.options,
    this.userAnswer,
    this.isCorrect,
  });

  final String id;
  final LearningQuestionType type;
  final VocabularyItem vocabularyItem;
  final String questionText;
  final String correctAnswer;
  final List<String> options;
  final String? userAnswer;
  final bool? isCorrect;

  LearningQuestion copyWith({
    String? id,
    LearningQuestionType? type,
    VocabularyItem? vocabularyItem,
    String? questionText,
    String? correctAnswer,
    List<String>? options,
    String? userAnswer,
    bool? isCorrect,
  }) {
    return LearningQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      vocabularyItem: vocabularyItem ?? this.vocabularyItem,
      questionText: questionText ?? this.questionText,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}
