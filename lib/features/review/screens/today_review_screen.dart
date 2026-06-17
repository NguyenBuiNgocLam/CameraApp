import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/tts_service.dart';
import '../../learning/models/learning_question.dart';
import '../../learning/models/learning_word.dart';
import '../../learning/models/review_word.dart';
import '../../learning/screens/unified_vocabulary_learning_screen.dart';
import '../../learning/services/global_review_service.dart';

class TodayReviewScreen extends StatefulWidget {
  const TodayReviewScreen({this.autoStart = false, super.key});

  final bool autoStart;

  @override
  State<TodayReviewScreen> createState() => _TodayReviewScreenState();
}

class _TodayReviewScreenState extends State<TodayReviewScreen> {
  final _reviewService = GlobalReviewService();
  final _ttsService = TtsService();

  bool _loaded = false;
  bool _isLoading = true;
  bool _isReviewing = false;
  bool _isCompleted = false;
  String? _errorMessage;
  List<ReviewWord> _reviewWords = [];
  List<LearningQuestion> _questions = [];
  int _currentIndex = 0;
  bool _isAnswered = false;
  int _correctCount = 0;
  int _wrongCount = 0;

  LearningQuestion? get _currentQuestion {
    if (_questions.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentIndex];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadReviewWords();
  }

  Future<void> _loadReviewWords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = context.read<AuthProvider>().user?.uid ?? '';
      final words = await _reviewService.getTodayReviewWords(uid, limit: 20);
      if (!mounted) return;
      setState(() {
        _reviewWords = words;
        _isLoading = false;
      });
      if (widget.autoStart && words.isNotEmpty) {
        _startReview();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startReview() {
    if (_reviewWords.isEmpty) return;
    final questions = _reviewService.generateReviewQuestions(_reviewWords);
    setState(() {
      _questions = questions;
      _currentIndex = 0;
      _isAnswered = false;
      _isReviewing = questions.isNotEmpty;
      _isCompleted = false;
      _correctCount = 0;
      _wrongCount = 0;
    });
  }

  Future<void> _submitInputAnswer(String input) async {
    final question = _currentQuestion;
    if (question == null || question.type != LearningQuestionType.inputWord) {
      return;
    }
    final normalizedInput = _normalizeText(input);
    if (normalizedInput.isEmpty) {
      setState(() => _errorMessage = 'Please enter the English word.');
      return;
    }
    await _answerQuestion(
      userAnswer: input.trim(),
      isCorrect: normalizedInput == _normalizeText(question.correctAnswer),
    );
  }

  Future<void> _selectOption(String option) async {
    final question = _currentQuestion;
    if (question == null ||
        question.type != LearningQuestionType.chooseMeaning) {
      return;
    }
    await _answerQuestion(
      userAnswer: option,
      isCorrect: option.trim() == question.correctAnswer.trim(),
    );
  }

  Future<void> _answerTrueFalse(bool value) async {
    final question = _currentQuestion;
    if (question == null || question.type != LearningQuestionType.trueFalse) {
      return;
    }
    await _answerQuestion(
      userAnswer: value.toString(),
      isCorrect: value.toString() == question.correctAnswer,
    );
  }

  Future<void> _answerQuestion({
    required String userAnswer,
    required bool isCorrect,
  }) async {
    final question = _currentQuestion;
    if (question == null || _isAnswered) return;

    final reviewWord = _reviewWordFor(question.word);
    if (reviewWord == null) return;

    setState(() {
      _isAnswered = true;
      _errorMessage = null;
      if (isCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
      _questions =
          _questions.asMap().entries.map((entry) {
            if (entry.key != _currentIndex) return entry.value;
            return entry.value.copyWith(
              userAnswer: userAnswer,
              isCorrect: isCorrect,
            );
          }).toList();
    });

    try {
      final uid = context.read<AuthProvider>().user?.uid ?? '';
      await _reviewService.updateReviewResult(
        uid: uid,
        word: reviewWord,
        isCorrect: isCorrect,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _goNext() {
    if (_currentIndex >= _questions.length - 1) {
      setState(() {
        _isReviewing = false;
        _isCompleted = true;
      });
      return;
    }

    setState(() {
      _currentIndex++;
      _isAnswered = false;
      _errorMessage = null;
    });
  }

  Future<void> _speak(LearningWord word) async {
    await _ttsService.speak(word.word);
  }

  ReviewWord? _reviewWordFor(LearningWord word) {
    for (final reviewWord in _reviewWords) {
      if (reviewWord.sourceType == word.sourceType &&
          reviewWord.id == word.id) {
        return reviewWord;
      }
    }
    return null;
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReviewing) {
      return UnifiedVocabularyLearningScreen(
        title: 'Today Review',
        mode: LearningSessionMode.review,
        questions: _questions,
        currentIndex: _currentIndex,
        isAnswered: _isAnswered,
        onSpeak: _speak,
        onFlashcardLevel: (_) {},
        onSubmitInputAnswer: _submitInputAnswer,
        onSelectOption: _selectOption,
        onAnswerTrueFalse: _answerTrueFalse,
        onNext: _goNext,
        emptyTitle: 'No words to review today',
        emptyMessage: 'Your spaced repetition queue is clear for now.',
      );
    }

    if (_isCompleted) {
      return _ReviewCompletedView(
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        total: _questions.length,
        onBackHome: () => Navigator.pop(context),
      );
    }

    final colors = Theme.of(context).colorScheme;

    return MainScaffold(
      currentIndex: 0,
      appBar: AppBar(title: const Text('Today Review')),
      child:
          _isLoading
              ? const LoadingWidget(message: 'Loading review words...')
              : _errorMessage != null
              ? ErrorStateWidget(
                title: 'Cannot load review',
                message: _errorMessage!,
                onRetry: _loadReviewWords,
              )
              : _reviewWords.isEmpty
              ? const EmptyStateWidget(
                title: 'Great! No words to review today.',
                message: 'Your spaced repetition queue is clear for now.',
                icon: Icons.verified_rounded,
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: Icon(
                              Icons.event_available_rounded,
                              color: colors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Today Review',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_reviewWords.length} words are ready to review today.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 18),
                          CustomButton(
                            label: 'Start Review',
                            icon: Icons.school_rounded,
                            onPressed: _startReview,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Review Queue',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._reviewWords.map(
                      (word) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  word.sourceType == LearningSourceType.system
                                      ? Icons.public_rounded
                                      : Icons.menu_book_rounded,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      word.word,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      word.meaningVi,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _ReviewCompletedView extends StatelessWidget {
  const _ReviewCompletedView({
    required this.correctCount,
    required this.wrongCount,
    required this.total,
    required this.onBackHome,
  });

  final int correctCount;
  final int wrongCount;
  final int total;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MainScaffold(
      currentIndex: 0,
      appBar: AppBar(title: const Text('Today Review')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: colors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Review completed',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total words reviewed',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ResultTile(
                    label: 'Correct',
                    value: '$correctCount',
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultTile(
                    label: 'Wrong',
                    value: '$wrongCount',
                    icon: Icons.error_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            CustomButton(
              label: 'Back Home',
              icon: Icons.home_rounded,
              onPressed: onBackHome,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
