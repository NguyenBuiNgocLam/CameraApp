import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/vocabulary_item.dart';
import '../../../services/tts_service.dart';
import '../models/learning_question.dart';
import '../services/vocabulary_learning_service.dart';

enum VocabularyLearningMode { all, wrongOnly, unknownOnly }

class VocabularyLearningProvider extends ChangeNotifier {
  VocabularyLearningProvider({
    required VocabularyLearningService learningService,
    required TtsService ttsService,
  }) : _learningService = learningService,
       _ttsService = ttsService;

  final VocabularyLearningService _learningService;
  final TtsService _ttsService;

  bool isLoading = false;
  String? errorMessage;
  List<VocabularyItem> words = [];
  List<LearningQuestion> questions = [];
  int currentIndex = 0;
  bool isAnswered = false;
  bool? lastAnswerCorrect;
  int correctCount = 0;
  int wrongCount = 0;
  int masteredCount = 0;
  int temporaryCount = 0;
  int unknownCount = 0;
  bool isFinished = false;
  String? currentListId;

  LearningQuestion? get currentQuestion {
    if (questions.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  Future<void> startLearning({
    VocabularyLearningMode mode = VocabularyLearningMode.all,
    String? listId,
  }) async {
    isLoading = true;
    errorMessage = null;
    isFinished = false;
    notifyListeners();

    try {
      final uid = _currentUserId();
      final targetListId = listId ?? currentListId;
      if (targetListId == null || targetListId.trim().isEmpty) {
        throw Exception('Please choose a word list to learn.');
      }
      currentListId = targetListId;
      final loadedWords = await _learningService.getWordsForLearning(
        uid: uid,
        listId: targetListId,
        limit: 20,
      );
      words = _filterWords(loadedWords, mode);
      if (words.isEmpty) {
        questions = [];
        currentIndex = 0;
        isAnswered = false;
        lastAnswerCorrect = null;
        errorMessage = 'Bạn chưa có từ vựng phù hợp để học.';
      } else {
        questions = _learningService.generateLearningSession(words);
        if (questions.isEmpty) {
          errorMessage = 'Từ vựng cần có cả từ tiếng Anh và nghĩa tiếng Việt.';
        }
        currentIndex = 0;
        isAnswered = false;
        lastAnswerCorrect = null;
      }
      correctCount = 0;
      wrongCount = 0;
      masteredCount = 0;
      temporaryCount = 0;
      unknownCount = 0;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> answerFlashcardLevel(String level) async {
    final normalizedLevel = _normalizeLearningLevel(level);
    final isCorrect = normalizedLevel != 'unknown';
    await _answerCurrentQuestion(
      userAnswer: normalizedLevel,
      isCorrect: isCorrect,
      learningLevel: normalizedLevel,
      hasSeenFlashcard: true,
    );

    switch (normalizedLevel) {
      case 'mastered':
        masteredCount++;
      case 'temporary':
        temporaryCount++;
      default:
        unknownCount++;
    }
    notifyListeners();
  }

  Future<void> submitInputAnswer(String input) async {
    final question = currentQuestion;
    if (question == null || question.type != LearningQuestionType.inputWord) {
      return;
    }

    final normalizedInput = _normalizeText(input);
    if (normalizedInput.isEmpty) {
      errorMessage = 'Vui lòng nhập từ tiếng Anh.';
      notifyListeners();
      return;
    }

    final isCorrect = normalizedInput == _normalizeText(question.correctAnswer);
    await _answerCurrentQuestion(
      userAnswer: input.trim(),
      isCorrect: isCorrect,
    );
  }

  Future<void> selectOption(String option) async {
    final question = currentQuestion;
    if (question == null ||
        question.type != LearningQuestionType.chooseMeaning) {
      return;
    }

    await _answerCurrentQuestion(
      userAnswer: option,
      isCorrect: option.trim() == question.correctAnswer.trim(),
    );
  }

  Future<void> answerTrueFalse(bool value) async {
    final question = currentQuestion;
    if (question == null || question.type != LearningQuestionType.trueFalse) {
      return;
    }

    await _answerCurrentQuestion(
      userAnswer: value.toString(),
      isCorrect: value.toString() == question.correctAnswer,
    );
  }

  void goNext() {
    if (questions.isEmpty) return;
    if (currentIndex >= questions.length - 1) {
      finishLearning();
      return;
    }

    currentIndex++;
    isAnswered = false;
    lastAnswerCorrect = null;
    errorMessage = null;
    notifyListeners();
  }

  void finishLearning() {
    isFinished = true;
    isAnswered = false;
    notifyListeners();
  }

  void resetLearning() {
    isLoading = false;
    errorMessage = null;
    words = [];
    questions = [];
    currentIndex = 0;
    isAnswered = false;
    lastAnswerCorrect = null;
    correctCount = 0;
    wrongCount = 0;
    masteredCount = 0;
    temporaryCount = 0;
    unknownCount = 0;
    isFinished = false;
    currentListId = null;
    notifyListeners();
  }

  Future<void> speakCurrentWord() async {
    final word = currentQuestion?.vocabularyItem.word;
    if (word == null || word.trim().isEmpty) return;
    await _ttsService.speak(word);
  }

  Future<void> _answerCurrentQuestion({
    required String userAnswer,
    required bool isCorrect,
    String? learningLevel,
    bool? hasSeenFlashcard,
  }) async {
    final question = currentQuestion;
    if (question == null || isAnswered) return;

    isAnswered = true;
    lastAnswerCorrect = isCorrect;
    if (isCorrect) {
      correctCount++;
    } else {
      wrongCount++;
    }

    questions =
        questions.asMap().entries.map((entry) {
          if (entry.key != currentIndex) return entry.value;
          return entry.value.copyWith(
            userAnswer: userAnswer,
            isCorrect: isCorrect,
          );
        }).toList();
    notifyListeners();

    try {
      final uid = _currentUserId();
      await _learningService.updateLearningResult(
        uid: uid,
        item: question.vocabularyItem,
        isCorrect: isCorrect,
        learningLevel: learningLevel,
        hasSeenFlashcard: hasSeenFlashcard,
      );
      _updateLocalWord(
        question.vocabularyItem,
        isCorrect: isCorrect,
        learningLevel: learningLevel,
        hasSeenFlashcard: hasSeenFlashcard,
      );
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  void _updateLocalWord(
    VocabularyItem item, {
    required bool isCorrect,
    String? learningLevel,
    bool? hasSeenFlashcard,
  }) {
    final now = DateTime.now();
    final level = learningLevel ?? item.learningLevel;
    words =
        words.map((word) {
          if (word.id != item.id) return word;
          return word.copyWith(
            learningLevel: learningLevel,
            correctCount: word.correctCount + (isCorrect ? 1 : 0),
            wrongCount: word.wrongCount + (isCorrect ? 0 : 1),
            hasSeenFlashcard: hasSeenFlashcard,
            lastReviewedAt: now,
            nextReviewAt: _nextReviewDate(now, level),
          );
        }).toList();
  }

  List<VocabularyItem> _filterWords(
    List<VocabularyItem> source,
    VocabularyLearningMode mode,
  ) {
    return switch (mode) {
      VocabularyLearningMode.wrongOnly =>
        source.where((word) => word.wrongCount > 0).toList(),
      VocabularyLearningMode.unknownOnly =>
        source.where((word) => word.learningLevel == 'unknown').toList(),
      VocabularyLearningMode.all => source,
    };
  }

  String _currentUserId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please login before learning vocabulary.');
    }
    return uid;
  }

  String _normalizeLearningLevel(String level) {
    return switch (level) {
      'mastered' => 'mastered',
      'temporary' => 'temporary',
      _ => 'unknown',
    };
  }

  String _normalizeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  DateTime _nextReviewDate(DateTime now, String level) {
    return switch (level) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 2)),
      _ => now.add(const Duration(days: 1)),
    };
  }
}
