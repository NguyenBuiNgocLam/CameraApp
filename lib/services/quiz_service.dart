import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/quiz_models.dart';
import '../models/vocabulary_item.dart';
import 'firestore_service.dart';

class QuizService {
  QuizService({required FirestoreService firestore}) : _firestore = firestore;

  final FirestoreService _firestore;
  static const _uuid = Uuid();

  List<QuizQuestion> buildQuestions(List<VocabularyItem> items) {
    if (items.length < 4) {
      throw Exception('You need at least 4 saved words to start a quiz.');
    }

    final random = Random();
    final shuffled = [...items]..shuffle(random);
    return shuffled.take(min(5, shuffled.length)).map((item) {
      final askMeaning = random.nextBool();
      final wrongPool =
          items.where((candidate) => candidate.id != item.id).toList()
            ..shuffle(random);
      final correct = askMeaning ? item.meaningVi : item.word;
      final wrongOptions =
          wrongPool
              .take(3)
              .map(
                (candidate) =>
                    askMeaning ? candidate.meaningVi : candidate.word,
              )
              .toList();
      final options = [correct, ...wrongOptions]..shuffle(random);
      return QuizQuestion(
        question:
            askMeaning
                ? 'What is the Vietnamese meaning of ${item.word}?'
                : 'Which English word means ${item.meaningVi}?',
        options: options,
        correctIndex: options.indexOf(correct),
      );
    }).toList();
  }

  Future<void> saveResult({
    required String userId,
    required int score,
    required int totalQuestions,
  }) async {
    final result = QuizResult(
      id: _uuid.v4(),
      userId: userId,
      score: score,
      totalQuestions: totalQuestions,
      correctAnswers: score,
      wrongAnswers: totalQuestions - score,
      createdAt: DateTime.now(),
    );
    await _firestore.saveQuizResult(result);
  }

  Future<List<QuizResult>> loadResults(String userId) {
    return _firestore.getQuizResults(userId);
  }
}
