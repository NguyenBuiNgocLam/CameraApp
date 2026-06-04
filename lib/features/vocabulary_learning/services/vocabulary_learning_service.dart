import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/vocabulary_item.dart';
import '../models/learning_question.dart';

class VocabularyLearningService {
  VocabularyLearningService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random();

  Future<List<VocabularyItem>> getWordsForLearning({
    required String uid,
    required String listId,
    int limit = 20,
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

    final words =
        snapshot.docs
            .map(VocabularyItem.fromFirestore)
            .where(_hasLearningContent)
            .toList();

    words.sort(_compareLearningPriority);
    return words.take(min(limit, 20)).toList();
  }

  List<LearningQuestion> generateLearningSession(List<VocabularyItem> words) {
    final usableWords = words.where(_hasLearningContent).toList();
    if (usableWords.isEmpty) return const [];

    final sessionWords = usableWords.take(min(20, usableWords.length)).toList();
    final questions = <LearningQuestion>[];

    for (final item in sessionWords) {
      if (!item.hasSeenFlashcard) {
        questions.add(_flashcardQuestion(item));
      }
      questions.add(_inputWordQuestion(item));

      final chooseMeaning = _chooseMeaningQuestion(item, usableWords);
      if (chooseMeaning != null) questions.add(chooseMeaning);

      final trueFalse = _trueFalseQuestion(item, usableWords);
      if (trueFalse != null) questions.add(trueFalse);
    }

    questions.shuffle(_random);
    final firstFlashcardIndex = questions.indexWhere(
      (question) => question.type == LearningQuestionType.flashcard,
    );
    if (firstFlashcardIndex > 0) {
      final firstFlashcard = questions.removeAt(firstFlashcardIndex);
      questions.insert(0, firstFlashcard);
    }
    return questions.take(min(20, questions.length)).toList();
  }

  Future<void> updateLearningResult({
    required String uid,
    required VocabularyItem item,
    required bool isCorrect,
    String? learningLevel,
    bool? hasSeenFlashcard,
  }) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before updating learning progress.');
    }
    if (item.id.trim().isEmpty) {
      throw Exception('Cannot update this vocabulary item.');
    }

    final now = DateTime.now();
    final level = learningLevel ?? item.learningLevel;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('vocabulary')
        .doc(item.id)
        .set({
          if (isCorrect)
            'correctCount': FieldValue.increment(1)
          else
            'wrongCount': FieldValue.increment(1),
          if (learningLevel != null) 'learningLevel': learningLevel,
          if (hasSeenFlashcard != null) 'hasSeenFlashcard': hasSeenFlashcard,
          'lastReviewedAt': Timestamp.fromDate(now),
          'nextReviewAt': Timestamp.fromDate(_nextReviewDate(now, level)),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
  }

  bool _hasLearningContent(VocabularyItem item) {
    return item.word.trim().isNotEmpty && item.meaningVi.trim().isNotEmpty;
  }

  int _compareLearningPriority(VocabularyItem a, VocabularyItem b) {
    if (a.hasSeenFlashcard != b.hasSeenFlashcard) {
      return a.hasSeenFlashcard ? 1 : -1;
    }

    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final levelCompare = _levelWeight(
      b.learningLevel,
    ).compareTo(_levelWeight(a.learningLevel));
    if (levelCompare != 0) return levelCompare;

    final aReviewed = a.lastReviewedAt;
    final bReviewed = b.lastReviewedAt;
    if (aReviewed == null && bReviewed != null) return -1;
    if (aReviewed != null && bReviewed == null) return 1;
    if (aReviewed == null && bReviewed == null) return 0;
    return aReviewed!.compareTo(bReviewed!);
  }

  int _levelWeight(String level) {
    return switch (level) {
      'unknown' => 3,
      'temporary' => 2,
      'mastered' => 1,
      _ => 3,
    };
  }

  LearningQuestion _flashcardQuestion(VocabularyItem item) {
    return LearningQuestion(
      id: '${item.id}-flashcard',
      type: LearningQuestionType.flashcard,
      vocabularyItem: item,
      questionText: item.word,
      correctAnswer: item.meaningVi,
      options: const [],
    );
  }

  LearningQuestion _inputWordQuestion(VocabularyItem item) {
    return LearningQuestion(
      id: '${item.id}-input',
      type: LearningQuestionType.inputWord,
      vocabularyItem: item,
      questionText: item.meaningVi,
      correctAnswer: item.word,
      options: const [],
    );
  }

  LearningQuestion? _chooseMeaningQuestion(
    VocabularyItem item,
    List<VocabularyItem> allWords,
  ) {
    final wrongOptions =
        allWords
            .where((word) => word.id != item.id)
            .map((word) => word.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != item.meaningVi)
            .toSet()
            .toList()
          ..shuffle(_random);

    if (wrongOptions.length < 3) return null;

    final options = [item.meaningVi, ...wrongOptions.take(3)]..shuffle(_random);
    return LearningQuestion(
      id: '${item.id}-choose',
      type: LearningQuestionType.chooseMeaning,
      vocabularyItem: item,
      questionText: item.word,
      correctAnswer: item.meaningVi,
      options: options,
    );
  }

  LearningQuestion? _trueFalseQuestion(
    VocabularyItem item,
    List<VocabularyItem> allWords,
  ) {
    final otherMeanings =
        allWords
            .where((word) => word.id != item.id)
            .map((word) => word.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != item.meaningVi)
            .toSet()
            .toList();

    if (otherMeanings.isEmpty) return null;

    final isTrue = _random.nextBool();
    final shownMeaning =
        isTrue
            ? item.meaningVi
            : otherMeanings[_random.nextInt(otherMeanings.length)];

    return LearningQuestion(
      id: '${item.id}-true-false',
      type: LearningQuestionType.trueFalse,
      vocabularyItem: item,
      questionText: shownMeaning,
      correctAnswer: isTrue.toString(),
      options: const ['true', 'false'],
    );
  }

  DateTime _nextReviewDate(DateTime now, String level) {
    return switch (level) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 2)),
      _ => now.add(const Duration(days: 1)),
    };
  }
}
