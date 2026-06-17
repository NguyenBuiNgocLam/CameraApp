import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/learning_question.dart';
import '../models/learning_word.dart';
import '../models/review_word.dart';

class GlobalReviewService {
  GlobalReviewService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random();

  Future<int> getTodayReviewCount(String uid) async {
    final words = await getTodayReviewWords(uid, limit: 1000);
    return words.length;
  }

  Future<List<ReviewWord>> getTodayReviewWords(
    String uid, {
    int limit = 20,
  }) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before reviewing vocabulary.');
    }

    final systemWords = await _getSystemDueWords(uid);
    final userWords = await _getUserDueWords(uid);
    final words = [...systemWords, ...userWords]..sort(_compareReviewWords);
    return words.take(limit.clamp(1, 1000)).toList();
  }

  List<LearningQuestion> generateReviewQuestions(List<ReviewWord> words) {
    final usableWords =
        words
            .where(
              (word) =>
                  word.word.trim().isNotEmpty &&
                  word.meaningVi.trim().isNotEmpty,
            )
            .take(20)
            .toList();
    if (usableWords.isEmpty) return const [];

    final questions = <LearningQuestion>[];
    for (var index = 0; index < usableWords.length; index++) {
      final word = usableWords[index];
      questions.add(_practiceQuestion(word, usableWords, index));
    }
    questions.shuffle(_random);
    return questions.asMap().entries.map((entry) {
      return entry.value.copyWith(questionIndex: entry.key);
    }).toList();
  }

  Future<void> updateReviewResult({
    required String uid,
    required ReviewWord word,
    required bool isCorrect,
  }) async {
    if (word.sourceType == LearningSourceType.system) {
      final progressId = word.progressId;
      if (progressId == null || progressId.trim().isEmpty) {
        throw Exception('Cannot update this system vocabulary progress.');
      }
      await _updateProgressDocument(
        _userRef(uid).collection('systemVocabularyProgress').doc(progressId),
        currentCorrectCount: word.correctCount,
        isCorrect: isCorrect,
      );
      return;
    }

    final vocabularyId = word.vocabularyId ?? word.id;
    await _updateProgressDocument(
      _userRef(uid).collection('vocabulary').doc(vocabularyId),
      currentCorrectCount: word.correctCount,
      isCorrect: isCorrect,
    );
  }

  Future<List<ReviewWord>> _getSystemDueWords(String uid) async {
    final snapshot =
        await _userRef(uid).collection('systemVocabularyProgress').get();
    final progressDocs =
        snapshot.docs.where((doc) => _isDueProgress(doc.data())).toList();
    final words = <ReviewWord>[];

    for (final doc in progressDocs) {
      final progress = doc.data();
      final setId = _readString(progress['setId']);
      final wordId = _readString(progress['wordId']);
      if (setId.isEmpty || wordId.isEmpty) continue;

      final wordDoc =
          await _firestore
              .collection('systemVocabularySets')
              .doc(setId)
              .collection('words')
              .doc(wordId)
              .get();
      if (!wordDoc.exists) continue;

      final data = wordDoc.data() ?? {};
      words.add(
        ReviewWord(
          id: doc.id,
          sourceType: LearningSourceType.system,
          setId: setId,
          wordId: wordId,
          progressId: doc.id,
          word: _readString(data['word']),
          meaningVi: _readString(data['meaningVi']),
          partOfSpeech: _readString(data['partOfSpeech']),
          topic: _readString(data['topic']),
          learningLevel: _readLearningLevel(progress['learningLevel']),
          correctCount: _readInt(progress['correctCount']),
          wrongCount: _readInt(progress['wrongCount']),
          hasSeenFlashcard: progress['hasSeenFlashcard'] == true,
          lastReviewedAt: _readNullableDate(progress['lastReviewedAt']),
          nextReviewAt: _readNullableDate(progress['nextReviewAt']),
        ),
      );
    }

    return words;
  }

  Future<List<ReviewWord>> _getUserDueWords(String uid) async {
    final snapshot = await _userRef(uid).collection('vocabulary').get();
    return snapshot.docs
        .where((doc) => _isDueProgress(doc.data()))
        .map((doc) {
          final data = doc.data();
          return ReviewWord(
            id: doc.id,
            sourceType: LearningSourceType.userVocabulary,
            vocabularyId: doc.id,
            listId: _readString(data['listId']),
            word: _readString(data['word']),
            meaningVi: _readString(data['meaningVi']),
            phonetic: _readString(data['phonetic']),
            partOfSpeech: _readString(data['partOfSpeech']),
            exampleEn: _readString(data['exampleEn']),
            exampleVi: _readString(data['exampleVi']),
            topic: _readString(data['sourceContext']),
            learningLevel: _readLearningLevel(data['learningLevel']),
            correctCount: _readInt(data['correctCount']),
            wrongCount: _readInt(data['wrongCount']),
            hasSeenFlashcard: data['hasSeenFlashcard'] == true,
            lastReviewedAt: _readNullableDate(data['lastReviewedAt']),
            nextReviewAt: _readNullableDate(data['nextReviewAt']),
          );
        })
        .where(
          (word) =>
              word.word.trim().isNotEmpty && word.meaningVi.trim().isNotEmpty,
        )
        .toList();
  }

  bool _isDueProgress(Map<String, dynamic> data) {
    final nextReviewAt = _readNullableDate(data['nextReviewAt']);
    if (nextReviewAt == null || nextReviewAt.isAfter(_endOfToday())) {
      return false;
    }
    return data['hasSeenFlashcard'] == true ||
        _readNullableDate(data['lastReviewedAt']) != null ||
        _readInt(data['correctCount']) > 0 ||
        _readInt(data['wrongCount']) > 0;
  }

  LearningQuestion _practiceQuestion(
    ReviewWord word,
    List<ReviewWord> pool,
    int index,
  ) {
    final type = _questionTypeForIndex(index);
    if (type == LearningQuestionType.trueFalse) {
      return _trueFalseQuestion(word, pool, index);
    }
    if (type == LearningQuestionType.chooseMeaning &&
        _hasMeaningDistractor(word, pool)) {
      return _chooseMeaningQuestion(word, pool, index);
    }
    return _inputWordQuestion(word, index);
  }

  LearningQuestion _inputWordQuestion(ReviewWord word, int index) {
    return LearningQuestion(
      id: '${word.sourceType.name}_${word.id}_input_$index',
      type: LearningQuestionType.inputWord,
      word: word.toLearningWord(),
      correctAnswer: word.word,
      options: const [],
      displayedMeaning: word.meaningVi,
      questionIndex: index,
    );
  }

  LearningQuestion _chooseMeaningQuestion(
    ReviewWord word,
    List<ReviewWord> pool,
    int index,
  ) {
    final wrongOptions =
        pool
            .where((item) => item.id != word.id)
            .map((item) => item.meaningVi.trim())
            .where((meaning) => meaning.isNotEmpty && meaning != word.meaningVi)
            .toSet()
            .toList()
          ..shuffle(_random);
    final options = [word.meaningVi, ...wrongOptions.take(3)]..shuffle(_random);
    return LearningQuestion(
      id: '${word.sourceType.name}_${word.id}_choose_$index',
      type: LearningQuestionType.chooseMeaning,
      word: word.toLearningWord(),
      correctAnswer: word.meaningVi,
      options: options,
      displayedMeaning: word.word,
      questionIndex: index,
    );
  }

  LearningQuestion _trueFalseQuestion(
    ReviewWord word,
    List<ReviewWord> pool,
    int index,
  ) {
    final otherMeanings =
        pool
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
    return LearningQuestion(
      id: '${word.sourceType.name}_${word.id}_true_false_$index',
      type: LearningQuestionType.trueFalse,
      word: word.toLearningWord(),
      correctAnswer: isTrue.toString(),
      options: const ['true', 'false'],
      displayedMeaning: shownMeaning,
      isCorrectMeaning: isTrue,
      questionIndex: index,
    );
  }

  Future<void> _updateProgressDocument(
    DocumentReference<Map<String, dynamic>> ref, {
    required int currentCorrectCount,
    required bool isCorrect,
  }) async {
    final now = DateTime.now();
    final nextCorrectCount = currentCorrectCount + (isCorrect ? 1 : 0);
    final learningLevel =
        isCorrect
            ? (nextCorrectCount >= 3 ? 'mastered' : 'temporary')
            : 'unknown';
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

  int _compareReviewWords(ReviewWord a, ReviewWord b) {
    final aDue = a.nextReviewAt;
    final bDue = b.nextReviewAt;
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
    }

    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final levelCompare = _levelWeight(
      a.learningLevel,
    ).compareTo(_levelWeight(b.learningLevel));
    if (levelCompare != 0) return levelCompare;

    return a.word.toLowerCase().compareTo(b.word.toLowerCase());
  }

  int _levelWeight(String level) {
    return switch (level.trim().toLowerCase()) {
      'unknown' => 0,
      'temporary' => 1,
      'mastered' => 2,
      _ => 3,
    };
  }

  LearningQuestionType _questionTypeForIndex(int index) {
    return switch (index % 3) {
      0 => LearningQuestionType.trueFalse,
      1 => LearningQuestionType.chooseMeaning,
      _ => LearningQuestionType.inputWord,
    };
  }

  bool _hasMeaningDistractor(ReviewWord word, List<ReviewWord> pool) {
    return pool.any(
      (item) =>
          item.id != word.id &&
          item.meaningVi.trim().isNotEmpty &&
          item.meaningVi.trim() != word.meaningVi.trim(),
    );
  }

  DateTime? _readNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _readInt(dynamic value) {
    return (value as num?)?.toInt() ?? 0;
  }

  String _readString(dynamic value) {
    return (value as String?)?.trim() ?? '';
  }

  String _readLearningLevel(dynamic value) {
    final level = _readString(value).toLowerCase();
    if (level == 'mastered' || level == 'temporary') return level;
    return 'unknown';
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }
}
