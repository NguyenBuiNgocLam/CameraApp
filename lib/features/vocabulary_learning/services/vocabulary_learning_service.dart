import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../learning/models/learning_question.dart' as unified;
import '../../learning/models/learning_word.dart';
import '../../../models/vocabulary_item.dart';
import '../models/learning_question.dart' as legacy;

class VocabularyLearningService {
  VocabularyLearningService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random();

  Future<List<VocabularyItem>> selectWordsForLearningSession({
    required String uid,
    required String listId,
    int limit = 10,
  }) async {
    final words = await _loadWordsByList(uid: uid, listId: listId);
    words.sort(_compareLearningPriority);
    return words.take(limit.clamp(1, 10)).toList();
  }

  Future<List<VocabularyItem>> getWordsForLearning({
    required String uid,
    required String listId,
    int limit = 10,
  }) {
    return selectWordsForLearningSession(
      uid: uid,
      listId: listId,
      limit: limit,
    );
  }

  Future<List<VocabularyItem>> getReviewWords({
    required String uid,
    required String listId,
    int limit = 20,
  }) async {
    final words = await _loadWordsByList(uid: uid, listId: listId);
    final endOfToday = _endOfToday();
    final dueWords =
        words.where((word) {
            final nextReviewAt = word.nextReviewAt;
            return _isLearned(word) &&
                nextReviewAt != null &&
                !nextReviewAt.isAfter(endOfToday);
          }).toList()
          ..sort(_compareReviewPriority);

    return dueWords.take(limit.clamp(1, 20)).toList();
  }

  Future<List<VocabularyItem>> getTodayReviewWords({
    required String uid,
    String? listId,
    int limit = 20,
  }) async {
    final targetListId = listId?.trim();
    if (targetListId == null || targetListId.isEmpty) {
      final words = await _loadAllWords(uid);
      final endOfToday = _endOfToday();
      final dueWords =
          words.where((word) {
              final nextReviewAt = word.nextReviewAt;
              return _isLearned(word) &&
                  nextReviewAt != null &&
                  !nextReviewAt.isAfter(endOfToday);
            }).toList()
            ..sort(_compareReviewPriority);
      return dueWords.take(limit.clamp(1, 20)).toList();
    }
    return getReviewWords(uid: uid, listId: targetListId, limit: limit);
  }

  Future<int> getDueReviewCount({
    required String uid,
    required String listId,
  }) async {
    final words = await _loadWordsByList(uid: uid, listId: listId);
    final endOfToday = _endOfToday();
    return words.where((word) {
      final nextReviewAt = word.nextReviewAt;
      return _isLearned(word) &&
          nextReviewAt != null &&
          !nextReviewAt.isAfter(endOfToday);
    }).length;
  }

  Future<List<VocabularyItem>> getWordsByList({
    required String uid,
    required String listId,
  }) {
    return _loadWordsByList(uid: uid, listId: listId);
  }

  Future<List<legacy.LearningQuestion>> generateLearningSession({
    required String uid,
    required String listId,
    required List<VocabularyItem> words,
    required bool includeFlashcards,
    int targetPracticeCount = 20,
  }) async {
    final usableWords = words.where(_hasLearningContent).take(20).toList();
    if (usableWords.isEmpty) return const [];

    final pool = await _loadAllWords(uid);
    final flashcards = <legacy.LearningQuestion>[];
    final practice = <legacy.LearningQuestion>[];

    if (includeFlashcards) {
      for (final item in usableWords.take(10)) {
        flashcards.add(_flashcardQuestion(item));
      }
    }

    final maxPractice =
        includeFlashcards
            ? (usableWords.length >= 10
                ? targetPracticeCount
                : min(targetPracticeCount, max(2, usableWords.length * 3)))
            : min(targetPracticeCount, max(1, usableWords.length * 3));
    for (var index = 0; index < maxPractice; index++) {
      final item = usableWords[index % usableWords.length];
      practice.add(_practiceQuestion(item, pool, index, maxPractice));
    }

    practice.shuffle(_random);
    return [...flashcards, ...practice];
  }

  Future<List<unified.LearningQuestion>> generateUnifiedLearningSession({
    required String uid,
    required String listId,
    required List<VocabularyItem> words,
    required bool includeFlashcards,
    int targetPracticeCount = 20,
  }) async {
    final usableWords = words.where(_hasLearningContent).take(20).toList();
    if (usableWords.isEmpty) return const [];

    final pool = await _loadAllWords(uid);
    final learningWords =
        usableWords.map(LearningWord.fromUserVocabularyItem).toList();
    final learningPool = pool.map(LearningWord.fromUserVocabularyItem).toList();
    final flashcards = <unified.LearningQuestion>[];
    final practice = <unified.LearningQuestion>[];

    if (includeFlashcards) {
      for (final word in learningWords.take(10)) {
        flashcards.add(_unifiedFlashcardQuestion(word));
      }
    }

    final maxPractice =
        includeFlashcards
            ? (learningWords.length >= 10
                ? targetPracticeCount
                : min(targetPracticeCount, max(2, learningWords.length * 3)))
            : min(targetPracticeCount, max(1, learningWords.length * 3));
    for (var index = 0; index < maxPractice; index++) {
      final word = learningWords[index % learningWords.length];
      practice.add(
        _unifiedPracticeQuestion(word, learningPool, index, maxPractice),
      );
    }

    practice.shuffle(_random);
    return [...flashcards, ...practice];
  }

  Future<void> updateFlashcardLevel({
    required String uid,
    required String vocabularyId,
    required String level,
  }) async {
    final normalizedLevel = _normalizeLearningLevel(level);
    final now = DateTime.now();
    final nextReviewAt = switch (normalizedLevel) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };

    await _vocabularyRef(uid, vocabularyId).set({
      'learningLevel': normalizedLevel,
      'hasSeenFlashcard': true,
      'lastReviewedAt': Timestamp.fromDate(now),
      'nextReviewAt': Timestamp.fromDate(nextReviewAt),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  Future<void> updatePracticeResult({
    required String uid,
    required String vocabularyId,
    required bool isCorrect,
  }) async {
    final ref = _vocabularyRef(uid, vocabularyId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw Exception('Cannot update this vocabulary item.');
    }

    final item = VocabularyItem.fromFirestore(snapshot);
    final correctCount = item.correctCount + (isCorrect ? 1 : 0);
    final learningLevel =
        isCorrect ? (correctCount >= 3 ? 'mastered' : 'temporary') : 'unknown';

    final now = DateTime.now();
    final nextReviewAt = switch (learningLevel) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };

    await ref.set({
      if (isCorrect)
        'correctCount': FieldValue.increment(1)
      else
        'wrongCount': FieldValue.increment(1),
      'learningLevel': learningLevel,
      'lastReviewedAt': Timestamp.fromDate(now),
      'nextReviewAt': Timestamp.fromDate(nextReviewAt),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  Future<void> updateLearningResult({
    required String uid,
    required VocabularyItem item,
    required bool isCorrect,
    String? learningLevel,
    bool? hasSeenFlashcard,
  }) {
    if (hasSeenFlashcard == true && learningLevel != null) {
      return updateFlashcardLevel(
        uid: uid,
        vocabularyId: item.id,
        level: learningLevel,
      );
    }
    return updatePracticeResult(
      uid: uid,
      vocabularyId: item.id,
      isCorrect: isCorrect,
    );
  }

  bool _hasLearningContent(VocabularyItem item) {
    return item.word.trim().isNotEmpty && item.meaningVi.trim().isNotEmpty;
  }

  bool _isLearned(VocabularyItem item) {
    return item.hasSeenFlashcard || item.lastReviewedAt != null;
  }

  int _compareLearningPriority(VocabularyItem a, VocabularyItem b) {
    if (a.hasSeenFlashcard != b.hasSeenFlashcard) {
      return a.hasSeenFlashcard ? 1 : -1;
    }

    final aNeverReviewed = a.lastReviewedAt == null;
    final bNeverReviewed = b.lastReviewedAt == null;
    if (aNeverReviewed != bNeverReviewed) return aNeverReviewed ? -1 : 1;

    final aUnknown = a.learningLevel == 'unknown';
    final bUnknown = b.learningLevel == 'unknown';
    if (aUnknown != bUnknown) return aUnknown ? -1 : 1;

    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final now = _endOfToday();
    final aDue = a.nextReviewAt != null && !a.nextReviewAt!.isAfter(now);
    final bDue = b.nextReviewAt != null && !b.nextReviewAt!.isAfter(now);
    if (aDue != bDue) return aDue ? -1 : 1;

    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareReviewPriority(VocabularyItem a, VocabularyItem b) {
    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final aDue = a.nextReviewAt;
    final bDue = b.nextReviewAt;
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
    }

    final levelCompare = _levelWeight(
      a.learningLevel,
    ).compareTo(_levelWeight(b.learningLevel));
    if (levelCompare != 0) return levelCompare;

    return a.word.toLowerCase().compareTo(b.word.toLowerCase());
  }

  int _levelWeight(String level) {
    return switch (level) {
      'unknown' => 0,
      'temporary' => 1,
      'mastered' => 2,
      _ => 3,
    };
  }

  legacy.LearningQuestion _flashcardQuestion(VocabularyItem item) {
    return legacy.LearningQuestion(
      id: '${item.id}-flashcard',
      type: legacy.LearningQuestionType.flashcard,
      vocabularyItem: item,
      questionText: item.word,
      correctAnswer: item.meaningVi,
      options: const [],
    );
  }

  legacy.LearningQuestion _practiceQuestion(
    VocabularyItem item,
    List<VocabularyItem> allWords,
    int index,
    int totalPracticeCount,
  ) {
    final type = _practiceTypeForIndex(index, totalPracticeCount);
    if (type == legacy.LearningQuestionType.trueFalse) {
      return _trueFalseQuestion(item, allWords, index);
    }
    if (type == legacy.LearningQuestionType.chooseMeaning &&
        _hasEnoughMeaningOptions(item, allWords)) {
      return _chooseMeaningQuestion(item, allWords, index);
    }
    return _inputWordQuestion(item, index);
  }

  legacy.LearningQuestion _inputWordQuestion(VocabularyItem item, int index) {
    return legacy.LearningQuestion(
      id: '${item.id}-input-$index',
      type: legacy.LearningQuestionType.inputWord,
      vocabularyItem: item,
      questionText: item.meaningVi,
      correctAnswer: item.word,
      options: const [],
    );
  }

  legacy.LearningQuestion _chooseMeaningQuestion(
    VocabularyItem item,
    List<VocabularyItem> allWords,
    int index,
  ) {
    final wrongOptions =
        allWords
            .where((word) => word.id != item.id)
            .map((word) => word.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != item.meaningVi)
            .toSet()
            .toList()
          ..shuffle(_random);

    final options = [item.meaningVi, ...wrongOptions.take(3)]..shuffle(_random);
    return legacy.LearningQuestion(
      id: '${item.id}-choose-$index',
      type: legacy.LearningQuestionType.chooseMeaning,
      vocabularyItem: item,
      questionText: item.word,
      correctAnswer: item.meaningVi,
      options: options,
    );
  }

  legacy.LearningQuestion _trueFalseQuestion(
    VocabularyItem item,
    List<VocabularyItem> allWords,
    int index,
  ) {
    final otherMeanings =
        allWords
            .where((word) => word.id != item.id)
            .map((word) => word.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != item.meaningVi)
            .toSet()
            .toList();

    final isTrue = otherMeanings.isEmpty ? true : index.isEven;
    final shownMeaning =
        isTrue
            ? item.meaningVi
            : otherMeanings[_random.nextInt(otherMeanings.length)];

    return legacy.LearningQuestion(
      id: '${item.id}-true-false-$index',
      type: legacy.LearningQuestionType.trueFalse,
      vocabularyItem: item,
      questionText: shownMeaning,
      correctAnswer: isTrue.toString(),
      options: const ['true', 'false'],
    );
  }

  unified.LearningQuestion _unifiedFlashcardQuestion(LearningWord word) {
    return unified.LearningQuestion(
      id: '${word.id}-flashcard',
      type: unified.LearningQuestionType.flashcard,
      word: word,
      correctAnswer: word.meaningVi,
      options: const [],
      questionIndex: 0,
    );
  }

  unified.LearningQuestion _unifiedPracticeQuestion(
    LearningWord word,
    List<LearningWord> allWords,
    int index,
    int totalPracticeCount,
  ) {
    final type = _practiceTypeForIndex(index, totalPracticeCount);
    if (type == legacy.LearningQuestionType.trueFalse) {
      return _unifiedTrueFalseQuestion(word, allWords, index);
    }
    if (type == legacy.LearningQuestionType.chooseMeaning &&
        _hasEnoughUnifiedMeaningOptions(word, allWords)) {
      return _unifiedChooseMeaningQuestion(word, allWords, index);
    }
    return _unifiedInputWordQuestion(word, index);
  }

  unified.LearningQuestion _unifiedInputWordQuestion(
    LearningWord word,
    int index,
  ) {
    return unified.LearningQuestion(
      id: '${word.id}-input-$index',
      type: unified.LearningQuestionType.inputWord,
      word: word,
      correctAnswer: word.word,
      options: const [],
      displayedMeaning: word.meaningVi,
      questionIndex: index,
    );
  }

  unified.LearningQuestion _unifiedChooseMeaningQuestion(
    LearningWord word,
    List<LearningWord> allWords,
    int index,
  ) {
    final wrongOptions =
        allWords
            .where((item) => item.id != word.id)
            .map((item) => item.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != word.meaningVi)
            .toSet()
            .toList()
          ..shuffle(_random);

    final options = [word.meaningVi, ...wrongOptions.take(3)]..shuffle(_random);
    return unified.LearningQuestion(
      id: '${word.id}-choose-$index',
      type: unified.LearningQuestionType.chooseMeaning,
      word: word,
      correctAnswer: word.meaningVi,
      options: options,
      displayedMeaning: word.word,
      questionIndex: index,
    );
  }

  unified.LearningQuestion _unifiedTrueFalseQuestion(
    LearningWord word,
    List<LearningWord> allWords,
    int index,
  ) {
    final otherMeanings =
        allWords
            .where((item) => item.id != word.id)
            .map((item) => item.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != word.meaningVi)
            .toSet()
            .toList();

    final isTrue = otherMeanings.isEmpty ? true : index.isEven;
    final shownMeaning =
        isTrue
            ? word.meaningVi
            : otherMeanings[_random.nextInt(otherMeanings.length)];

    return unified.LearningQuestion(
      id: '${word.id}-true-false-$index',
      type: unified.LearningQuestionType.trueFalse,
      word: word,
      correctAnswer: isTrue.toString(),
      options: const ['true', 'false'],
      displayedMeaning: shownMeaning,
      isCorrectMeaning: isTrue,
      questionIndex: index,
    );
  }

  Future<List<VocabularyItem>> _loadWordsByList({
    required String uid,
    required String listId,
  }) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before learning vocabulary.');
    }
    if (listId.trim().isEmpty) {
      throw Exception('Please choose a word list to learn.');
    }

    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('vocabulary')
            .where('listId', isEqualTo: listId)
            .get();

    return snapshot.docs
        .map(VocabularyItem.fromFirestore)
        .where(_hasLearningContent)
        .toList();
  }

  Future<List<VocabularyItem>> _loadAllWords(String uid) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before learning vocabulary.');
    }
    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('vocabulary')
            .get();
    return snapshot.docs
        .map(VocabularyItem.fromFirestore)
        .where(_hasLearningContent)
        .toList();
  }

  DocumentReference<Map<String, dynamic>> _vocabularyRef(
    String uid,
    String vocabularyId,
  ) {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before updating learning progress.');
    }
    if (vocabularyId.trim().isEmpty) {
      throw Exception('Cannot update this vocabulary item.');
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('vocabulary')
        .doc(vocabularyId);
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  String _normalizeLearningLevel(String level) {
    final normalized = level.trim().toLowerCase();
    if (normalized == 'mastered' || normalized == 'temporary') {
      return normalized;
    }
    return 'unknown';
  }

  legacy.LearningQuestionType _practiceTypeForIndex(
    int index,
    int totalPracticeCount,
  ) {
    if (totalPracticeCount >= 20) {
      if (index < 7) return legacy.LearningQuestionType.trueFalse;
      if (index < 14) return legacy.LearningQuestionType.chooseMeaning;
      return legacy.LearningQuestionType.inputWord;
    }

    return switch (index % 3) {
      0 => legacy.LearningQuestionType.trueFalse,
      1 => legacy.LearningQuestionType.chooseMeaning,
      _ => legacy.LearningQuestionType.inputWord,
    };
  }

  bool _hasEnoughMeaningOptions(
    VocabularyItem item,
    List<VocabularyItem> allWords,
  ) {
    return allWords.any(
      (word) =>
          word.id != item.id &&
          word.meaningVi.trim().isNotEmpty &&
          word.meaningVi.trim() != item.meaningVi.trim(),
    );
  }

  bool _hasEnoughUnifiedMeaningOptions(
    LearningWord word,
    List<LearningWord> allWords,
  ) {
    return allWords.any(
      (item) =>
          item.id != word.id &&
          item.meaningVi.trim().isNotEmpty &&
          item.meaningVi.trim() != word.meaningVi.trim(),
    );
  }
}
