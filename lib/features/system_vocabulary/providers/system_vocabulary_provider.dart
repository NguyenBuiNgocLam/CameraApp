import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../features/vocabulary_learning/models/learning_question.dart';
import '../../../models/vocabulary_item.dart';
import '../models/system_vocabulary_item.dart';
import '../models/system_vocabulary_progress.dart';
import '../models/system_vocabulary_set.dart';
import '../services/system_vocabulary_service.dart';

enum SystemVocabularyFilter {
  all,
  unknown,
  temporary,
  mastered,
  favorite,
  todayReview,
}

enum LearningSessionMode { learn, review }

extension SystemVocabularyFilterLabel on SystemVocabularyFilter {
  String get label {
    return switch (this) {
      SystemVocabularyFilter.all => 'All',
      SystemVocabularyFilter.unknown => 'Unknown',
      SystemVocabularyFilter.temporary => 'Temporary',
      SystemVocabularyFilter.mastered => 'Mastered',
      SystemVocabularyFilter.favorite => 'Favorite',
      SystemVocabularyFilter.todayReview => 'Today Review',
    };
  }
}

class SystemVocabularyProvider extends ChangeNotifier {
  SystemVocabularyProvider({
    SystemVocabularyService? systemVocabularyService,
    FirebaseAuth? firebaseAuth,
  }) : _systemVocabularyService =
           systemVocabularyService ?? SystemVocabularyService(),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final SystemVocabularyService _systemVocabularyService;
  final FirebaseAuth _firebaseAuth;

  bool isLoading = false;
  String? errorMessage;
  List<SystemVocabularySet> sets = [];
  SystemVocabularySet? selectedSet;
  List<SystemVocabularyItem> words = [];
  Map<String, SystemVocabularyProgress> progressMap = {};
  String searchQuery = '';
  String? selectedTopic;
  SystemVocabularyFilter selectedFilter = SystemVocabularyFilter.all;
  List<SystemVocabularyItem> learningWords = [];
  List<SystemVocabularyItem> reviewWords = [];
  List<LearningQuestion> questions = [];
  LearningSessionMode sessionMode = LearningSessionMode.learn;
  int currentIndex = 0;
  bool isAnswered = false;
  bool isFinished = false;
  bool isReviewLoading = false;
  int dueTodayCount = 0;
  int sessionCorrectCount = 0;
  int sessionWrongCount = 0;
  int sessionMasteredCount = 0;
  int sessionTemporaryCount = 0;
  int sessionUnknownCount = 0;

  static const int _targetFlashcardCount = 10;
  static const int _targetPracticeCount = 20;

  List<SystemVocabularyItem> get filteredWords {
    final query = searchQuery.trim().toLowerCase();
    final topic = selectedTopic?.trim();

    final now = DateTime.now();

    return words.where((word) {
        final matchesTopic =
            topic == null || topic.isEmpty || word.topic.trim() == topic;
        final matchesSearch =
            query.isEmpty ||
            word.word.toLowerCase().contains(query) ||
            word.meaningVi.toLowerCase().contains(query) ||
            word.partOfSpeech.toLowerCase().contains(query) ||
            word.topic.toLowerCase().contains(query);
        final progress = progressMap[word.id];
        final matchesFilter = _matchesFilter(progress, now);
        return matchesTopic && matchesSearch && matchesFilter;
      }).toList()
      ..sort((a, b) => a.no.compareTo(b.no));
  }

  List<String> get topics {
    return words
        .map((word) => word.topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  int get masteredCount {
    return progressMap.values
        .where((progress) => progress.learningLevel == 'mastered')
        .length;
  }

  int get learnedCount {
    return progressMap.values
        .where(
          (progress) => progress.hasSeenFlashcard || progress.wordId.isNotEmpty,
        )
        .length;
  }

  int get temporaryCount {
    return progressMap.values
        .where((progress) => progress.learningLevel == 'temporary')
        .length;
  }

  int get unknownCount {
    final knownWordIds = progressMap.keys.toSet();
    final unknownProgressCount =
        progressMap.values
            .where((progress) => progress.learningLevel == 'unknown')
            .length;
    final noProgressCount =
        words.where((word) => !knownWordIds.contains(word.id)).length;
    return unknownProgressCount + noProgressCount;
  }

  int get todayReviewCount => dueTodayCount;

  LearningQuestion? get currentQuestion {
    if (questions.isEmpty ||
        currentIndex < 0 ||
        currentIndex >= questions.length) {
      return null;
    }
    return questions[currentIndex];
  }

  double get sessionProgress {
    if (questions.isEmpty) return 0;
    return (currentIndex + 1) / questions.length;
  }

  int get sessionFlashcardCount {
    return questions
        .where((question) => question.type == LearningQuestionType.flashcard)
        .length;
  }

  int get sessionPracticeCount => questions.length - sessionFlashcardCount;

  int get currentFlashcardStep {
    if (currentQuestion?.type != LearningQuestionType.flashcard) return 0;
    return questions
        .take(currentIndex + 1)
        .where((question) => question.type == LearningQuestionType.flashcard)
        .length;
  }

  int get currentPracticeStep {
    if (currentQuestion?.type == LearningQuestionType.flashcard) return 0;
    return questions
        .take(currentIndex + 1)
        .where((question) => question.type != LearningQuestionType.flashcard)
        .length;
  }

  Future<void> loadSets() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      sets = await _systemVocabularyService.getSystemSets();
      selectedSet ??= sets.isEmpty ? null : sets.first;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> selectSet(SystemVocabularySet set) async {
    selectedSet = set;
    selectedTopic = null;
    searchQuery = '';
    selectedFilter = SystemVocabularyFilter.all;
    notifyListeners();
    await loadWords(set.id);
  }

  Future<void> loadWords(String setId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      words = await _systemVocabularyService.getWordsBySet(setId);
      await loadProgress(setId);
      await loadDueTodayCount(setId);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadProgress(String setId) async {
    final uid = _currentUserId();
    progressMap = await _systemVocabularyService.getUserProgressMap(
      uid: uid,
      setId: setId,
    );
  }

  Future<void> loadDueTodayCount(String setId) async {
    final uid = _currentUserId();
    dueTodayCount = await _systemVocabularyService.getDueReviewCount(
      uid: uid,
      setId: setId,
    );
  }

  Future<void> refreshProgressStats() async {
    final set = selectedSet;
    if (set == null) return;
    await loadProgress(set.id);
    await loadDueTodayCount(set.id);
    notifyListeners();
  }

  void updateSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void selectTopic(String? topic) {
    selectedTopic = topic;
    notifyListeners();
  }

  void selectFilter(SystemVocabularyFilter filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  Future<void> toggleFavorite(SystemVocabularyItem item) async {
    final uid = _currentUserId();
    final current = progressMap[item.id];
    final updated = await _systemVocabularyService.toggleFavorite(
      uid: uid,
      setId: item.setId,
      wordId: item.id,
      isFavorite: !(current?.isFavorite ?? false),
    );
    progressMap = {...progressMap, item.id: updated};
    notifyListeners();
  }

  Future<void> refresh() async {
    final set = selectedSet;
    if (set == null) {
      await loadSets();
      return;
    }
    await loadWords(set.id);
  }

  SystemVocabularyProgress? progressFor(SystemVocabularyItem item) {
    return progressMap[item.id];
  }

  Future<void> startLearningSet({bool todayReviewOnly = false}) async {
    if (todayReviewOnly) {
      await startReviewSession();
      return;
    }

    isLoading = true;
    errorMessage = null;
    sessionMode = LearningSessionMode.learn;
    notifyListeners();

    try {
      final set = selectedSet;
      if (set == null) {
        throw Exception('Please choose a vocabulary set first.');
      }
      if (words.isEmpty) {
        words = await _systemVocabularyService.getWordsBySet(set.id);
      }
      if (progressMap.isEmpty) {
        await loadProgress(set.id);
      }

      final selectedWords = selectWordsForSession(todayReviewOnly: false);
      learningWords = selectedWords;
      reviewWords = [];
      questions = generateSystemLearningSession(selectedWords);
      _resetSessionCounters(questions.isEmpty);

      if (questions.isEmpty) {
        errorMessage = 'No new system vocabulary available for learning.';
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> startReviewSession({String? setId}) async {
    isReviewLoading = true;
    errorMessage = null;
    sessionMode = LearningSessionMode.review;
    notifyListeners();

    try {
      final set = selectedSet;
      final targetSetId = setId ?? set?.id;
      if (targetSetId == null || targetSetId.isEmpty) {
        throw Exception('Please choose a vocabulary set first.');
      }

      if (words.isEmpty) {
        words = await _systemVocabularyService.getWordsBySet(targetSetId);
      }
      await loadProgress(targetSetId);
      dueTodayCount = await _systemVocabularyService.getDueReviewCount(
        uid: _currentUserId(),
        setId: targetSetId,
      );

      reviewWords = await _systemVocabularyService.getReviewWords(
        uid: _currentUserId(),
        setId: targetSetId,
      );
      learningWords = reviewWords;
      questions = _generateReviewQuestions(reviewWords);
      _resetSessionCounters(questions.isEmpty);

      if (questions.isEmpty) {
        errorMessage =
            progressMap.isEmpty
                ? 'You don\'t have any words to review yet. Start learning first.'
                : 'No review words for today.';
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isReviewLoading = false;
    notifyListeners();
  }

  List<SystemVocabularyItem> selectWordsForSession({
    required bool todayReviewOnly,
  }) {
    return _prioritizedLearningWords(
      todayReviewOnly: todayReviewOnly,
    ).take(_targetFlashcardCount).toList();
  }

  List<LearningQuestion> generateSystemLearningSession(
    List<SystemVocabularyItem> selectedWords,
  ) {
    return _generateQuestions(selectedWords);
  }

  Future<bool> answerFlashcardLevel(String learningLevel) async {
    final question = currentQuestion;
    if (question == null || question.type != LearningQuestionType.flashcard) {
      return false;
    }

    final normalizedLevel = _normalizeLearningLevel(learningLevel);
    final uid = _currentUserId();
    final item = question.vocabularyItem;
    final updated = await _systemVocabularyService.updateFlashcardLevel(
      uid: uid,
      setId: item.listId,
      wordId: item.id,
      learningLevel: normalizedLevel,
    );
    progressMap = {...progressMap, item.id: updated};
    dueTodayCount =
        progressMap.values.where((progress) {
          final nextReviewAt = progress.nextReviewAt;
          return nextReviewAt != null && !nextReviewAt.isAfter(_endOfToday());
        }).length;

    switch (normalizedLevel) {
      case 'mastered':
        sessionMasteredCount++;
        break;
      case 'temporary':
        sessionTemporaryCount++;
        break;
      default:
        sessionUnknownCount++;
    }

    if (currentIndex >= questions.length - 1) {
      isFinished = true;
    } else {
      currentIndex++;
      isAnswered = false;
    }
    notifyListeners();
    return isFinished;
  }

  Future<void> submitInputAnswer(String value) async {
    final question = currentQuestion;
    if (question == null || question.type != LearningQuestionType.inputWord) {
      return;
    }

    final isCorrect =
        _normalizeText(value) == _normalizeText(question.correctAnswer);
    await _answerQuestion(userAnswer: value.trim(), isCorrect: isCorrect);
  }

  Future<void> selectOption(String option) async {
    final question = currentQuestion;
    if (question == null ||
        question.type != LearningQuestionType.chooseMeaning) {
      return;
    }

    final isCorrect = option == question.correctAnswer;
    await _answerQuestion(userAnswer: option, isCorrect: isCorrect);
  }

  Future<void> answerTrueFalse(bool value) async {
    final question = currentQuestion;
    if (question == null || question.type != LearningQuestionType.trueFalse) {
      return;
    }

    final isCorrect = value.toString() == question.correctAnswer;
    await _answerQuestion(userAnswer: value.toString(), isCorrect: isCorrect);
  }

  void goNext() {
    if (questions.isEmpty) return;
    if (currentIndex >= questions.length - 1) {
      isFinished = true;
    } else {
      currentIndex++;
      isAnswered = questions[currentIndex].isCorrect != null;
    }
    notifyListeners();
  }

  void resetLearningSession() {
    learningWords = [];
    reviewWords = [];
    questions = [];
    sessionMode = LearningSessionMode.learn;
    currentIndex = 0;
    isAnswered = false;
    isFinished = false;
    sessionCorrectCount = 0;
    sessionWrongCount = 0;
    sessionMasteredCount = 0;
    sessionTemporaryCount = 0;
    sessionUnknownCount = 0;
    notifyListeners();
  }

  bool _matchesFilter(SystemVocabularyProgress? progress, DateTime now) {
    final level = progress?.learningLevel.trim().toLowerCase() ?? 'unknown';
    final nextReviewAt = progress?.nextReviewAt;

    return switch (selectedFilter) {
      SystemVocabularyFilter.all => true,
      SystemVocabularyFilter.unknown => level == 'unknown',
      SystemVocabularyFilter.temporary => level == 'temporary',
      SystemVocabularyFilter.mastered => level == 'mastered',
      SystemVocabularyFilter.favorite => progress?.isFavorite ?? false,
      SystemVocabularyFilter.todayReview =>
        nextReviewAt != null && !nextReviewAt.isAfter(_endOfToday(now)),
    };
  }

  String _currentUserId() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please login before using system vocabulary.');
    }
    return uid;
  }

  Future<void> _answerQuestion({
    required String userAnswer,
    required bool isCorrect,
  }) async {
    final question = currentQuestion;
    if (question == null || isAnswered) return;

    final uid = _currentUserId();
    final item = question.vocabularyItem;
    final updated = await _systemVocabularyService.updatePracticeResult(
      uid: uid,
      setId: item.listId,
      wordId: item.id,
      isCorrect: isCorrect,
    );

    progressMap = {...progressMap, item.id: updated};
    dueTodayCount =
        progressMap.values.where((progress) {
          final nextReviewAt = progress.nextReviewAt;
          return nextReviewAt != null && !nextReviewAt.isAfter(_endOfToday());
        }).length;
    questions[currentIndex] = question.copyWith(
      userAnswer: userAnswer,
      isCorrect: isCorrect,
    );
    isAnswered = true;
    if (isCorrect) {
      sessionCorrectCount++;
    } else {
      sessionWrongCount++;
    }
    notifyListeners();
  }

  List<SystemVocabularyItem> _prioritizedLearningWords({
    required bool todayReviewOnly,
  }) {
    final candidates =
        words.where((word) {
          final progress = progressMap[word.id];
          if (!todayReviewOnly) {
            return progress == null ||
                !progress.hasSeenFlashcard ||
                progress.learningLevel == 'unknown';
          }
          final nextReviewAt = progress?.nextReviewAt;
          return nextReviewAt != null && !nextReviewAt.isAfter(_endOfToday());
        }).toList();

    candidates.sort((a, b) {
      final priorityA = _learningPriority(a);
      final priorityB = _learningPriority(b);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);

      final wrongA = progressMap[a.id]?.wrongCount ?? 0;
      final wrongB = progressMap[b.id]?.wrongCount ?? 0;
      if (wrongA != wrongB) return wrongB.compareTo(wrongA);

      return a.no.compareTo(b.no);
    });

    return candidates;
  }

  int _learningPriority(SystemVocabularyItem word) {
    final progress = progressMap[word.id];
    if (progress == null) return 0;
    if (!progress.hasSeenFlashcard) return 1;
    if (progress.learningLevel == 'unknown') return 2;
    return 3;
  }

  List<LearningQuestion> _generateQuestions(List<SystemVocabularyItem> items) {
    final flashcards = <LearningQuestion>[];
    final practice = <LearningQuestion>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final progress = progressMap[item.id];
      final vocabularyItem = _toVocabularyItem(item, progress);

      flashcards.add(
        LearningQuestion(
          id: 'system_${item.id}_flashcard',
          type: LearningQuestionType.flashcard,
          vocabularyItem: vocabularyItem,
          questionText: item.word,
          correctAnswer: item.meaningVi,
          options: const [],
        ),
      );
    }

    final targetPracticeCount =
        items.length >= _targetFlashcardCount
            ? _targetPracticeCount
            : items.length * 2;
    for (var index = 0; index < targetPracticeCount; index++) {
      final item = items[index % items.length];
      final progress = progressMap[item.id];
      final vocabularyItem = _toVocabularyItem(item, progress);
      practice.add(_practiceQuestion(item, vocabularyItem, index));
    }

    practice.shuffle();
    return [...flashcards, ...practice];
  }

  List<LearningQuestion> _generateReviewQuestions(
    List<SystemVocabularyItem> items,
  ) {
    final reviewItems = items.take(20).toList();
    final practice = <LearningQuestion>[];
    for (var index = 0; index < reviewItems.length; index++) {
      final item = reviewItems[index];
      final progress = progressMap[item.id];
      final vocabularyItem = _toVocabularyItem(item, progress);
      practice.add(_practiceQuestion(item, vocabularyItem, index + 7));
    }

    practice.shuffle();
    return practice;
  }

  LearningQuestion _practiceQuestion(
    SystemVocabularyItem item,
    VocabularyItem vocabularyItem,
    int index,
  ) {
    if (index < 7) {
      final isTrue = index.isEven;
      final statement = isTrue ? item.meaningVi : _wrongMeaningFor(item);
      return LearningQuestion(
        id: 'system_${item.id}_true_false_$index',
        type: LearningQuestionType.trueFalse,
        vocabularyItem: vocabularyItem,
        questionText: statement,
        correctAnswer: isTrue.toString(),
        options: const ['true', 'false'],
      );
    }

    if (index < 14) {
      return LearningQuestion(
        id: 'system_${item.id}_choose_$index',
        type: LearningQuestionType.chooseMeaning,
        vocabularyItem: vocabularyItem,
        questionText: item.word,
        correctAnswer: item.meaningVi,
        options: _meaningOptions(item),
      );
    }

    return LearningQuestion(
      id: 'system_${item.id}_input_$index',
      type: LearningQuestionType.inputWord,
      vocabularyItem: vocabularyItem,
      questionText: item.meaningVi,
      correctAnswer: item.word,
      options: const [],
    );
  }

  List<String> _meaningOptions(SystemVocabularyItem item) {
    final options = <String>{item.meaningVi};
    final pool =
        words
            .where(
              (word) => word.id != item.id && word.meaningVi.trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.no.compareTo(b.no));

    for (final word in pool) {
      options.add(word.meaningVi);
      if (options.length >= 4) break;
    }

    return options.toList()..shuffle();
  }

  String _wrongMeaningFor(SystemVocabularyItem item) {
    return words
        .firstWhere(
          (word) => word.id != item.id && word.meaningVi.trim().isNotEmpty,
          orElse: () => item,
        )
        .meaningVi;
  }

  VocabularyItem _toVocabularyItem(
    SystemVocabularyItem item,
    SystemVocabularyProgress? progress,
  ) {
    return VocabularyItem(
      id: item.id,
      userId: progress?.userId ?? _firebaseAuth.currentUser?.uid ?? '',
      word: item.word,
      meaningVi: item.meaningVi,
      phonetic: '',
      partOfSpeech: item.partOfSpeech,
      exampleEn: '',
      exampleVi: '',
      imageUrl: null,
      isFavorite: progress?.isFavorite ?? false,
      listId: item.setId,
      sourceContext: item.topic,
      learningLevel: progress?.learningLevel ?? 'unknown',
      correctCount: progress?.correctCount ?? 0,
      wrongCount: progress?.wrongCount ?? 0,
      hasSeenFlashcard: progress?.hasSeenFlashcard ?? false,
      lastReviewedAt: progress?.lastReviewedAt,
      nextReviewAt: progress?.nextReviewAt,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  void _resetSessionCounters(bool finished) {
    currentIndex = 0;
    isAnswered = false;
    isFinished = finished;
    sessionCorrectCount = 0;
    sessionWrongCount = 0;
    sessionMasteredCount = 0;
    sessionTemporaryCount = 0;
    sessionUnknownCount = 0;
  }

  DateTime _endOfToday([DateTime? value]) {
    final now = value ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  String _normalizeLearningLevel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'mastered' || normalized == 'temporary') {
      return normalized;
    }
    return 'unknown';
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
