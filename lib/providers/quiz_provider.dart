import 'package:flutter/foundation.dart';

import '../models/quiz_models.dart';
import '../models/vocabulary_item.dart';
import '../services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  QuizProvider(this._quizService);

  final QuizService _quizService;

  List<QuizQuestion> questions = [];
  List<QuizResult> results = [];
  int currentIndex = 0;
  int? selectedIndex;
  int score = 0;
  String? errorMessage;

  QuizQuestion? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];

  int get totalQuestions => questions.length;

  bool start(List<VocabularyItem> items) {
    try {
      questions = _quizService.buildQuestions(items);
      currentIndex = 0;
      selectedIndex = null;
      score = 0;
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      questions = [];
      notifyListeners();
      return false;
    }
  }

  void select(int index) {
    final question = currentQuestion;
    if (question == null || selectedIndex != null) return;
    selectedIndex = index;
    if (index == question.correctIndex) score++;
    notifyListeners();
  }

  bool next() {
    if (currentIndex >= questions.length - 1) return false;
    currentIndex++;
    selectedIndex = null;
    notifyListeners();
    return true;
  }

  Future<void> saveResult(String userId) async {
    if (questions.isEmpty) return;
    await _quizService.saveResult(
      userId: userId,
      score: score,
      totalQuestions: questions.length,
    );
    await loadResults(userId);
  }

  Future<void> loadResults(String userId) async {
    if (userId.isEmpty) return;
    results = await _quizService.loadResults(userId);
    notifyListeners();
  }

  int quizCompleted(String userId) {
    return results.where((result) => result.userId == userId).length;
  }

  int bestScore(String userId) {
    final userResults = results.where((result) => result.userId == userId);
    if (userResults.isEmpty) return 0;
    return userResults
        .map((result) => result.score)
        .reduce((a, b) => a > b ? a : b);
  }
}
