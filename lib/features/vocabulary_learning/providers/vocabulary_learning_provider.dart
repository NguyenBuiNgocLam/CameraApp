import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/vocabulary_item.dart';
import '../../../services/tts_service.dart';
import '../../activity/services/learning_activity_service.dart';
import '../../learning/models/learning_question.dart' as unified;
import '../../learning/models/learning_word.dart' as learning;
import '../models/learning_question.dart' as legacy;
import '../services/vocabulary_learning_service.dart';

enum VocabularyLearningMode { all, wrongOnly, unknownOnly }

enum VocabularyLearningSessionMode { learn, review }

class VocabularyLearningProvider extends ChangeNotifier {
  VocabularyLearningProvider({
    required VocabularyLearningService learningService,
    required TtsService ttsService,
    LearningActivityService? activityService,
  }) : _learningService = learningService,
       _ttsService = ttsService,
       _activityService = activityService ?? LearningActivityService();

  final VocabularyLearningService _learningService;
  final TtsService _ttsService;
  final LearningActivityService _activityService;

  bool isLoading = false;
  bool isReviewLoading = false;
  String? errorMessage;
  List<VocabularyItem> words = [];
  List<VocabularyItem> reviewWords = [];
  List<legacy.LearningQuestion> questions = [];
  List<unified.LearningQuestion> unifiedQuestions = [];
  VocabularyLearningSessionMode sessionMode =
      VocabularyLearningSessionMode.learn;
  int currentIndex = 0;
  bool isAnswered = false;
  bool? lastAnswerCorrect;
  int dueTodayCount = 0;
  int listTotalCount = 0;
  int learnedCount = 0;
  int listMasteredCount = 0;
  int listTemporaryCount = 0;
  int listUnknownCount = 0;
  int listWrongCount = 0;
  int correctCount = 0;
  int wrongCount = 0;
  int masteredCount = 0;
  int temporaryCount = 0;
  int unknownCount = 0;
  bool isFinished = false;
  String? currentListId;

  legacy.LearningQuestion? get currentQuestion {
    if (questions.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  unified.LearningQuestion? get currentUnifiedQuestion {
    if (unifiedQuestions.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= unifiedQuestions.length) {
      return null;
    }
    return unifiedQuestions[currentIndex];
  }

  learning.LearningSessionMode get unifiedSessionMode {
    return sessionMode == VocabularyLearningSessionMode.review
        ? learning.LearningSessionMode.review
        : learning.LearningSessionMode.learn;
  }

  int get sessionFlashcardCount {
    return questions
        .where(
          (question) => question.type == legacy.LearningQuestionType.flashcard,
        )
        .length;
  }

  int get sessionPracticeCount => questions.length - sessionFlashcardCount;

  int get currentFlashcardStep {
    if (currentQuestion?.type != legacy.LearningQuestionType.flashcard) {
      return 0;
    }
    return questions
        .take(currentIndex + 1)
        .where(
          (question) => question.type == legacy.LearningQuestionType.flashcard,
        )
        .length;
  }

  int get currentPracticeStep {
    if (currentQuestion?.type == legacy.LearningQuestionType.flashcard) {
      return 0;
    }
    return questions
        .take(currentIndex + 1)
        .where(
          (question) => question.type != legacy.LearningQuestionType.flashcard,
        )
        .length;
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
      final loadedWords = await _learningService.selectWordsForLearningSession(
        uid: uid,
        listId: targetListId,
        limit: 10,
      );
      words = _filterWords(loadedWords, mode);
      if (words.isEmpty) {
        _resetSession(finished: true);
        errorMessage = 'You do not have any suitable vocabulary to study.';
      } else {
        sessionMode = VocabularyLearningSessionMode.learn;
        reviewWords = [];
        questions = await _learningService.generateLearningSession(
          uid: uid,
          listId: targetListId,
          words: words,
          includeFlashcards: true,
        );
        unifiedQuestions = _toUnifiedQuestions(questions);
        if (questions.isEmpty) {
          errorMessage =
              'Vocabulary items must have both an English word and a Vietnamese meaning.';
        }
        _resetSession(finished: questions.isEmpty, keepQuestions: true);
      }
      await loadWordListStats(targetListId, notify: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> startTodayReview({String? listId}) async {
    isReviewLoading = true;
    errorMessage = null;
    isFinished = false;
    notifyListeners();

    try {
      final uid = _currentUserId();
      final targetListId = listId ?? currentListId;
      if (targetListId == null || targetListId.trim().isEmpty) {
        throw Exception('Please choose a word list to review.');
      }
      currentListId = targetListId;
      final loadedWords = await _learningService.getTodayReviewWords(
        uid: uid,
        listId: targetListId,
        limit: 20,
      );
      await _startSessionFromWords(
        loadedWords,
        mode: VocabularyLearningSessionMode.review,
        emptyMessage:
            loadedWords.isEmpty
                ? 'No words to review today.'
                : 'Great! No words to review today.',
      );
      await loadWordListStats(targetListId, notify: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isReviewLoading = false;
    notifyListeners();
  }

  Future<void> startReviewWithWords(List<VocabularyItem> reviewWords) async {
    await _startSessionFromWords(
      reviewWords,
      mode: VocabularyLearningSessionMode.review,
      emptyMessage: 'Great! No words to review today.',
    );
    notifyListeners();
  }

  Future<void> loadWordListStats(String listId, {bool notify = true}) async {
    final uid = _currentUserId();
    final listWords = await _learningService.getWordsByList(
      uid: uid,
      listId: listId,
    );
    learnedCount =
        listWords
            .where(
              (word) => word.hasSeenFlashcard || word.lastReviewedAt != null,
            )
            .length;
    listTotalCount = listWords.length;
    listMasteredCount =
        listWords.where((word) => word.learningLevel == 'mastered').length;
    listTemporaryCount =
        listWords.where((word) => word.learningLevel == 'temporary').length;
    listUnknownCount =
        listWords.where((word) => word.learningLevel == 'unknown').length;
    listWrongCount = listWords.where((word) => word.wrongCount > 0).length;
    dueTodayCount = await _learningService.getDueReviewCount(
      uid: uid,
      listId: listId,
    );
    if (notify) notifyListeners();
  }

  Future<void> refreshProgressStats(String listId) => loadWordListStats(listId);

  Future<void> answerFlashcardLevel(String level) async {
    final normalizedLevel = _normalizeLearningLevel(level);
    final question = currentQuestion;
    if (question == null ||
        question.type != legacy.LearningQuestionType.flashcard) {
      return;
    }

    try {
      final uid = _currentUserId();
      await _learningService.updateFlashcardLevel(
        uid: uid,
        vocabularyId: question.vocabularyItem.id,
        level: normalizedLevel,
      );
      _updateLocalWordAfterFlashcard(question.vocabularyItem, normalizedLevel);
      await _activityService.recordVocabularyReview(
        uid: uid,
        reviewedWords: 1,
        correctAnswers: normalizedLevel == 'unknown' ? 0 : 1,
        wrongAnswers: normalizedLevel == 'unknown' ? 1 : 0,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return;
    }

    switch (normalizedLevel) {
      case 'mastered':
        masteredCount++;
        break;
      case 'temporary':
        temporaryCount++;
        break;
      default:
        unknownCount++;
        break;
    }
    _goNextSilently();
    notifyListeners();
  }

  Future<void> submitInputAnswer(String input) async {
    final question = currentQuestion;
    if (question == null ||
        question.type != legacy.LearningQuestionType.inputWord) {
      return;
    }

    final normalizedInput = _normalizeText(input);
    if (normalizedInput.isEmpty) {
      errorMessage = 'Please enter the English word.';
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
        question.type != legacy.LearningQuestionType.chooseMeaning) {
      return;
    }

    await _answerCurrentQuestion(
      userAnswer: option,
      isCorrect: option.trim() == question.correctAnswer.trim(),
    );
  }

  Future<void> answerTrueFalse(bool value) async {
    final question = currentQuestion;
    if (question == null ||
        question.type != legacy.LearningQuestionType.trueFalse) {
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
    isReviewLoading = false;
    errorMessage = null;
    words = [];
    reviewWords = [];
    questions = [];
    unifiedQuestions = [];
    sessionMode = VocabularyLearningSessionMode.learn;
    currentIndex = 0;
    isAnswered = false;
    lastAnswerCorrect = null;
    dueTodayCount = 0;
    listTotalCount = 0;
    learnedCount = 0;
    listMasteredCount = 0;
    listTemporaryCount = 0;
    listUnknownCount = 0;
    listWrongCount = 0;
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

  Future<void> speakLearningWord(learning.LearningWord word) async {
    if (word.word.trim().isEmpty) return;
    await _ttsService.speak(word.word);
  }

  Future<void> _answerCurrentQuestion({
    required String userAnswer,
    required bool isCorrect,
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
    unifiedQuestions =
        unifiedQuestions.asMap().entries.map((entry) {
          if (entry.key != currentIndex) return entry.value;
          return entry.value.copyWith(
            userAnswer: userAnswer,
            isCorrect: isCorrect,
          );
        }).toList();
    notifyListeners();

    try {
      final uid = _currentUserId();
      await _learningService.updatePracticeResult(
        uid: uid,
        vocabularyId: question.vocabularyItem.id,
        isCorrect: isCorrect,
      );
      try {
        await _activityService.recordVocabularyReview(
          uid: uid,
          reviewedWords: 1,
          correctAnswers: isCorrect ? 1 : 0,
          wrongAnswers: isCorrect ? 0 : 1,
        );
      } catch (_) {}
      _updateLocalWord(question.vocabularyItem, isCorrect: isCorrect);
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  void _updateLocalWord(VocabularyItem item, {required bool isCorrect}) {
    final now = DateTime.now();
    final current = words.firstWhere(
      (word) => word.id == item.id,
      orElse: () => item,
    );
    final correctTotal = current.correctCount + (isCorrect ? 1 : 0);
    final level =
        isCorrect ? (correctTotal >= 3 ? 'mastered' : 'temporary') : 'unknown';
    final nextReviewAt = switch (level) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };
    words =
        words.map((word) {
          if (word.id != item.id) return word;
          return word.copyWith(
            learningLevel: level,
            correctCount: word.correctCount + (isCorrect ? 1 : 0),
            wrongCount: word.wrongCount + (isCorrect ? 0 : 1),
            lastReviewedAt: now,
            nextReviewAt: nextReviewAt,
            updatedAt: now,
          );
        }).toList();
    _recalculateSessionStats();
  }

  Future<void> _startSessionFromWords(
    List<VocabularyItem> source, {
    required VocabularyLearningSessionMode mode,
    required String emptyMessage,
  }) async {
    final uid = _currentUserId();
    final targetListId = currentListId ?? source.firstOrNull?.listId;
    words = source.take(20).toList();
    reviewWords = mode == VocabularyLearningSessionMode.review ? words : [];
    sessionMode = mode;
    questions =
        targetListId == null
            ? const []
            : await _learningService.generateLearningSession(
              uid: uid,
              listId: targetListId,
              words: words,
              includeFlashcards: mode == VocabularyLearningSessionMode.learn,
            );
    unifiedQuestions =
        targetListId == null ? const [] : _toUnifiedQuestions(questions);
    _resetSession(finished: questions.isEmpty, keepQuestions: true);
    errorMessage = questions.isEmpty ? emptyMessage : null;
  }

  List<unified.LearningQuestion> _toUnifiedQuestions(
    List<legacy.LearningQuestion> source,
  ) {
    return source.asMap().entries.map((entry) {
      final question = entry.value;
      final word = learning.LearningWord.fromUserVocabularyItem(
        question.vocabularyItem,
      );
      return unified.LearningQuestion(
        id: question.id,
        type: switch (question.type) {
          legacy.LearningQuestionType.flashcard =>
            unified.LearningQuestionType.flashcard,
          legacy.LearningQuestionType.inputWord =>
            unified.LearningQuestionType.inputWord,
          legacy.LearningQuestionType.chooseMeaning =>
            unified.LearningQuestionType.chooseMeaning,
          legacy.LearningQuestionType.trueFalse =>
            unified.LearningQuestionType.trueFalse,
        },
        word: word,
        correctAnswer: question.correctAnswer,
        options: question.options,
        displayedMeaning:
            question.type == legacy.LearningQuestionType.inputWord
                ? question.questionText
                : question.type == legacy.LearningQuestionType.trueFalse
                ? question.questionText
                : '',
        isCorrectMeaning:
            question.type == legacy.LearningQuestionType.trueFalse
                ? question.correctAnswer == 'true'
                : null,
        questionIndex: entry.key,
        userAnswer: question.userAnswer,
        isCorrect: question.isCorrect,
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
    return value
        .toLowerCase()
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _resetSession({required bool finished, bool keepQuestions = false}) {
    if (!keepQuestions) {
      questions = [];
      unifiedQuestions = [];
    }
    currentIndex = 0;
    isAnswered = false;
    lastAnswerCorrect = null;
    correctCount = 0;
    wrongCount = 0;
    masteredCount = 0;
    temporaryCount = 0;
    unknownCount = 0;
    isFinished = finished;
  }

  void _goNextSilently() {
    if (questions.isEmpty) return;
    if (currentIndex >= questions.length - 1) {
      finishLearning();
      return;
    }

    currentIndex++;
    isAnswered = false;
    lastAnswerCorrect = null;
    errorMessage = null;
  }

  void _updateLocalWordAfterFlashcard(VocabularyItem item, String level) {
    final now = DateTime.now();
    final nextReviewAt = switch (level) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };
    words =
        words.map((word) {
          if (word.id != item.id) return word;
          return word.copyWith(
            learningLevel: level,
            hasSeenFlashcard: true,
            lastReviewedAt: now,
            nextReviewAt: nextReviewAt,
            updatedAt: now,
          );
        }).toList();
    _recalculateSessionStats();
  }

  void _recalculateSessionStats() {
    final endOfToday = _endOfToday();
    dueTodayCount =
        words.where((word) {
          final nextReviewAt = word.nextReviewAt;
          return nextReviewAt != null && !nextReviewAt.isAfter(endOfToday);
        }).length;
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }
}
