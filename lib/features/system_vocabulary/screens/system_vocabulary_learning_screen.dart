import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../vocabulary_learning/models/learning_question.dart';
import '../providers/system_vocabulary_provider.dart';

class SystemVocabularyLearningScreen extends StatefulWidget {
  const SystemVocabularyLearningScreen({super.key});

  @override
  State<SystemVocabularyLearningScreen> createState() =>
      _SystemVocabularyLearningScreenState();
}

class _SystemVocabularyLearningScreenState
    extends State<SystemVocabularyLearningScreen> {
  final _answerController = TextEditingController();
  bool _cardFlipped = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _goNext(SystemVocabularyProvider provider) {
    final isLast = provider.currentIndex >= provider.questions.length - 1;
    provider.goNext();
    _answerController.clear();
    setState(() => _cardFlipped = false);

    if (isLast && mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.systemVocabularyLearningResult,
      );
    }
  }

  Future<void> _answerFlashcardLevel(
    SystemVocabularyProvider provider,
    String learningLevel,
  ) async {
    final isFinished = await provider.answerFlashcardLevel(learningLevel);
    _answerController.clear();
    if (!mounted) return;
    setState(() => _cardFlipped = false);

    if (isFinished) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.systemVocabularyLearningResult,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final question = provider.currentQuestion;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(
        title: Text(
          provider.sessionMode == LearningSessionMode.review
              ? 'Review Session'
              : 'System Learning',
        ),
      ),
      child:
          question == null
              ? const EmptyStateWidget(
                title: 'No questions available',
                message: 'Go back and start a learning session again.',
                icon: Icons.school_outlined,
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _ProgressHeader(provider: provider),
                  const SizedBox(height: 16),
                  switch (question.type) {
                    LearningQuestionType.flashcard => _FlashcardQuestion(
                      question: question,
                      isFlipped: _cardFlipped,
                      onFlip:
                          () => setState(() => _cardFlipped = !_cardFlipped),
                    ),
                    LearningQuestionType.inputWord => _InputWordQuestion(
                      question: question,
                      controller: _answerController,
                    ),
                    LearningQuestionType.chooseMeaning =>
                      _ChooseMeaningQuestion(question: question),
                    LearningQuestionType.trueFalse => _TrueFalseQuestion(
                      question: question,
                    ),
                  },
                  const SizedBox(height: 18),
                  if (provider.isAnswered)
                    _FeedbackCard(question: question)
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 18),
                  _ActionArea(
                    question: question,
                    answerController: _answerController,
                    onFlashcardLevel:
                        (level) => _answerFlashcardLevel(provider, level),
                    onNext: () => _goNext(provider),
                  ),
                ],
              ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.provider});

  final SystemVocabularyProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _ProgressTitle(provider: provider)),
              Text(
                '${(provider.sessionProgress * 100).round()}%',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: provider.sessionProgress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _ProgressTitle extends StatelessWidget {
  const _ProgressTitle({required this.provider});

  final SystemVocabularyProvider provider;

  @override
  Widget build(BuildContext context) {
    final question = provider.currentQuestion;
    final title =
        provider.sessionMode == LearningSessionMode.review
            ? 'Review ${provider.currentPracticeStep}/${provider.sessionPracticeCount}'
            : question?.type == LearningQuestionType.flashcard
            ? 'Flashcard ${provider.currentFlashcardStep}/${provider.sessionFlashcardCount}'
            : 'Practice ${provider.currentPracticeStep}/${provider.sessionPracticeCount}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          'Step ${provider.currentIndex + 1}/${provider.questions.length}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FlashcardQuestion extends StatelessWidget {
  const _FlashcardQuestion({
    required this.question,
    required this.isFlipped,
    required this.onFlip,
  });

  final LearningQuestion question;
  final bool isFlipped;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final item = question.vocabularyItem;
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          IconButton.filledTonal(
            tooltip: 'Pronounce',
            onPressed:
                () => context.read<VocabularyProvider>().speak(item.word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                isFlipped
                    ? Column(
                      key: const ValueKey('back'),
                      children: [
                        Text(
                          item.meaningVi,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.partOfSpeech,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        if (item.sourceContext.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _Pill(label: item.sourceContext),
                        ],
                      ],
                    )
                    : Column(
                      key: const ValueKey('front'),
                      children: [
                        Text(
                          item.word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.partOfSpeech,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: isFlipped ? 'Show word' : 'Flip card',
            icon: Icons.flip_rounded,
            style: CustomButtonStyle.secondary,
            onPressed: onFlip,
          ),
        ],
      ),
    );
  }
}

class _InputWordQuestion extends StatelessWidget {
  const _InputWordQuestion({required this.question, required this.controller});

  final LearningQuestion question;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type the English word',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              question.questionText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: question.isCorrect == null,
            decoration: const InputDecoration(
              labelText: 'Your answer',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChooseMeaningQuestion extends StatelessWidget {
  const _ChooseMeaningQuestion({required this.question});

  final LearningQuestion question;

  @override
  Widget build(BuildContext context) {
    final item = question.vocabularyItem;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose the meaning',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            item.word,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(item.partOfSpeech),
          const SizedBox(height: 18),
          ...question.options.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionButton(question: question, option: option),
            );
          }),
        ],
      ),
    );
  }
}

class _TrueFalseQuestion extends StatelessWidget {
  const _TrueFalseQuestion({required this.question});

  final LearningQuestion question;

  @override
  Widget build(BuildContext context) {
    final item = question.vocabularyItem;
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'True or False',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Text(
            item.word,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(question.questionText),
          ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.question,
    required this.answerController,
    required this.onFlashcardLevel,
    required this.onNext,
  });

  final LearningQuestion question;
  final TextEditingController answerController;
  final ValueChanged<String> onFlashcardLevel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();

    if (provider.isAnswered) {
      return CustomButton(
        label:
            provider.currentIndex >= provider.questions.length - 1
                ? 'Finish'
                : 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: onNext,
      );
    }

    return switch (question.type) {
      LearningQuestionType.flashcard => Column(
        children: [
          CustomButton(
            label: 'Thông thạo',
            icon: Icons.workspace_premium_rounded,
            onPressed: () => onFlashcardLevel('mastered'),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: 'Nhớ tạm',
            icon: Icons.psychology_alt_rounded,
            style: CustomButtonStyle.secondary,
            onPressed: () => onFlashcardLevel('temporary'),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: 'Chưa biết',
            icon: Icons.help_outline_rounded,
            style: CustomButtonStyle.outline,
            onPressed: () => onFlashcardLevel('unknown'),
          ),
        ],
      ),
      LearningQuestionType.inputWord => CustomButton(
        label: 'Check answer',
        icon: Icons.check_rounded,
        onPressed: () => provider.submitInputAnswer(answerController.text),
      ),
      LearningQuestionType.chooseMeaning => const SizedBox.shrink(),
      LearningQuestionType.trueFalse => Row(
        children: [
          Expanded(
            child: CustomButton(
              label: 'True',
              icon: Icons.check_rounded,
              onPressed: () => provider.answerTrueFalse(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CustomButton(
              label: 'False',
              icon: Icons.close_rounded,
              style: CustomButtonStyle.secondary,
              onPressed: () => provider.answerTrueFalse(false),
            ),
          ),
        ],
      ),
    };
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.question, required this.option});

  final LearningQuestion question;
  final String option;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final isAnswered = provider.isAnswered;
    final isSelected = question.userAnswer == option;
    final isCorrectOption = question.correctAnswer == option;
    final colors = Theme.of(context).colorScheme;

    Color? background;
    Color? foreground;
    if (isAnswered && isCorrectOption) {
      background = Colors.green.withValues(alpha: 0.16);
      foreground = Colors.green.shade800;
    } else if (isAnswered && isSelected && !isCorrectOption) {
      background = colors.error.withValues(alpha: 0.14);
      foreground = colors.error;
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isAnswered ? null : () => provider.selectOption(option),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(option, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.question});

  final LearningQuestion question;

  @override
  Widget build(BuildContext context) {
    final isCorrect = question.isCorrect ?? false;
    final color =
        isCorrect ? Colors.green : Theme.of(context).colorScheme.error;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCorrect
                  ? 'Correct!'
                  : 'Correct answer: ${question.correctAnswer}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
