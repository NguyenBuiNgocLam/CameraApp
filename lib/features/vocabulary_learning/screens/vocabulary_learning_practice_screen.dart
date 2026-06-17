import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../learning/screens/unified_vocabulary_learning_screen.dart';
import '../providers/vocabulary_learning_provider.dart';

class VocabularyLearningPracticeScreen extends StatelessWidget {
  const VocabularyLearningPracticeScreen({super.key});

  void _finish(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.vocabularyLearningResult);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyLearningProvider>();

    if (provider.unifiedQuestions.isEmpty) {
      return MainScaffold(
        currentIndex: 2,
        appBar: AppBar(title: const Text('Vocabulary Learning')),
        child: EmptyStateWidget(
          title:
              provider.sessionMode == VocabularyLearningSessionMode.review
                  ? 'No words to review today'
                  : 'No lessons yet',
          message:
              provider.errorMessage ??
              'Go back to a word list and start a learning session.',
          icon: Icons.school_rounded,
        ),
      );
    }

    return UnifiedVocabularyLearningScreen(
      title: 'Vocabulary Learning',
      mode: provider.unifiedSessionMode,
      questions: provider.unifiedQuestions,
      currentIndex: provider.currentIndex,
      isAnswered: provider.isAnswered,
      onSpeak: provider.speakLearningWord,
      onFlashcardLevel: (level) async {
        await provider.answerFlashcardLevel(level);
        if (!context.mounted) return;
        if (provider.isFinished) _finish(context);
      },
      onSubmitInputAnswer: provider.submitInputAnswer,
      onSelectOption: provider.selectOption,
      onAnswerTrueFalse: provider.answerTrueFalse,
      onNext: () {
        provider.goNext();
        if (provider.isFinished) _finish(context);
      },
      emptyTitle:
          provider.sessionMode == VocabularyLearningSessionMode.review
              ? 'No words to review today'
              : 'No questions available',
      emptyMessage:
          provider.errorMessage ??
          'Go back to a word list and start a learning session again.',
    );
  }
}
