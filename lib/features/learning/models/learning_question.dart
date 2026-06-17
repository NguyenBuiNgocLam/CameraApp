import 'learning_word.dart';

enum LearningQuestionType { flashcard, trueFalse, chooseMeaning, inputWord }

class LearningQuestion {
  const LearningQuestion({
    required this.id,
    required this.type,
    required this.word,
    required this.correctAnswer,
    required this.options,
    required this.questionIndex,
    this.displayedMeaning = '',
    this.isCorrectMeaning,
    this.userAnswer,
    this.isCorrect,
  });

  final String id;
  final LearningQuestionType type;
  final LearningWord word;
  final String correctAnswer;
  final List<String> options;
  final String displayedMeaning;
  final bool? isCorrectMeaning;
  final int questionIndex;
  final String? userAnswer;
  final bool? isCorrect;

  LearningQuestion copyWith({
    String? id,
    LearningQuestionType? type,
    LearningWord? word,
    String? correctAnswer,
    List<String>? options,
    String? displayedMeaning,
    bool? isCorrectMeaning,
    int? questionIndex,
    String? userAnswer,
    bool? isCorrect,
  }) {
    return LearningQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      word: word ?? this.word,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      displayedMeaning: displayedMeaning ?? this.displayedMeaning,
      isCorrectMeaning: isCorrectMeaning ?? this.isCorrectMeaning,
      questionIndex: questionIndex ?? this.questionIndex,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}
