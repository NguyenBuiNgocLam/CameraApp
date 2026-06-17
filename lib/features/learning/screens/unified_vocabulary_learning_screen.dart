import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/learning_question.dart';
import '../models/learning_word.dart';

class UnifiedVocabularyLearningScreen extends StatefulWidget {
  const UnifiedVocabularyLearningScreen({
    required this.title,
    required this.mode,
    required this.questions,
    required this.currentIndex,
    required this.isAnswered,
    required this.onFlashcardLevel,
    required this.onSubmitInputAnswer,
    required this.onSelectOption,
    required this.onAnswerTrueFalse,
    required this.onNext,
    this.onSpeak,
    this.emptyTitle = 'No questions available',
    this.emptyMessage = 'Go back and start a learning session again.',
    super.key,
  });

  final String title;
  final LearningSessionMode mode;
  final List<LearningQuestion> questions;
  final int currentIndex;
  final bool isAnswered;
  final ValueChanged<String> onFlashcardLevel;
  final ValueChanged<String> onSubmitInputAnswer;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<bool> onAnswerTrueFalse;
  final VoidCallback onNext;
  final ValueChanged<LearningWord>? onSpeak;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<UnifiedVocabularyLearningScreen> createState() =>
      _UnifiedVocabularyLearningScreenState();
}

class _UnifiedVocabularyLearningScreenState
    extends State<UnifiedVocabularyLearningScreen> {
  final _answerController = TextEditingController();
  bool _cardFlipped = false;
  String? _questionId;

  LearningQuestion? get _currentQuestion {
    if (widget.questions.isEmpty ||
        widget.currentIndex < 0 ||
        widget.currentIndex >= widget.questions.length) {
      return null;
    }
    return widget.questions[widget.currentIndex];
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    if (question == null) {
      return MainScaffold(
        currentIndex: 2,
        appBar: AppBar(title: Text(widget.title)),
        child: EmptyStateWidget(
          title: widget.emptyTitle,
          message: widget.emptyMessage,
          icon: Icons.school_outlined,
        ),
      );
    }

    if (_questionId != question.id) {
      _questionId = question.id;
      _cardFlipped = false;
      _answerController.clear();
    }

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: Text(widget.title)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _ProgressHeader(
            mode: widget.mode,
            questions: widget.questions,
            currentIndex: widget.currentIndex,
          ),
          const SizedBox(height: 16),
          switch (question.type) {
            LearningQuestionType.flashcard => _FlashcardQuestion(
              question: question,
              isFlipped: _cardFlipped,
              onFlip: () => setState(() => _cardFlipped = !_cardFlipped),
              onSpeak: widget.onSpeak,
            ),
            LearningQuestionType.inputWord => _InputWordQuestion(
              question: question,
              controller: _answerController,
            ),
            LearningQuestionType.chooseMeaning => _ChooseMeaningQuestion(
              question: question,
              onSelectOption: widget.onSelectOption,
            ),
            LearningQuestionType.trueFalse => _TrueFalseQuestion(
              question: question,
            ),
          },
          const SizedBox(height: 18),
          if (widget.isAnswered &&
              question.type != LearningQuestionType.flashcard)
            _FeedbackCard(question: question),
          const SizedBox(height: 18),
          _ActionArea(
            question: question,
            isAnswered: widget.isAnswered,
            isLast: widget.currentIndex >= widget.questions.length - 1,
            answerController: _answerController,
            onFlashcardLevel: widget.onFlashcardLevel,
            onSubmitInputAnswer: widget.onSubmitInputAnswer,
            onSelectOption: widget.onSelectOption,
            onAnswerTrueFalse: widget.onAnswerTrueFalse,
            onNext: () {
              widget.onNext();
              setState(() => _cardFlipped = false);
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.mode,
    required this.questions,
    required this.currentIndex,
  });

  final LearningSessionMode mode;
  final List<LearningQuestion> questions;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress =
        questions.isEmpty ? 0.0 : ((currentIndex + 1) / questions.length);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ProgressTitle(
                  mode: mode,
                  questions: questions,
                  currentIndex: currentIndex,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 9,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _ProgressTitle extends StatelessWidget {
  const _ProgressTitle({
    required this.mode,
    required this.questions,
    required this.currentIndex,
  });

  final LearningSessionMode mode;
  final List<LearningQuestion> questions;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final question = questions[currentIndex];
    final flashcardCount =
        questions
            .where((item) => item.type == LearningQuestionType.flashcard)
            .length;
    final practiceCount = questions.length - flashcardCount;
    final currentFlashcardStep =
        question.type != LearningQuestionType.flashcard
            ? 0
            : questions
                .take(currentIndex + 1)
                .where((item) => item.type == LearningQuestionType.flashcard)
                .length;
    final currentPracticeStep =
        question.type == LearningQuestionType.flashcard
            ? 0
            : questions
                .take(currentIndex + 1)
                .where((item) => item.type != LearningQuestionType.flashcard)
                .length;
    final title =
        mode == LearningSessionMode.review
            ? 'Review $currentPracticeStep/$practiceCount'
            : question.type == LearningQuestionType.flashcard
            ? 'Flashcard $currentFlashcardStep/$flashcardCount'
            : 'Practice $currentPracticeStep/$practiceCount';

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
          'Step ${currentIndex + 1}/${questions.length}',
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
    required this.onSpeak,
  });

  final LearningQuestion question;
  final bool isFlipped;
  final VoidCallback onFlip;
  final ValueChanged<LearningWord>? onSpeak;

  @override
  Widget build(BuildContext context) {
    final word = question.word;
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          IconButton.filledTonal(
            tooltip: 'Pronounce',
            onPressed: onSpeak == null ? null : () => onSpeak!(word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                isFlipped
                    ? _FlashcardBack(word: word)
                    : Column(
                      key: const ValueKey('front'),
                      children: [
                        Text(
                          word.word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (word.phonetic.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            word.phonetic,
                            style: TextStyle(color: colors.secondary),
                          ),
                        ],
                        if (word.partOfSpeech.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            word.partOfSpeech,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: isFlipped ? 'View front side' : 'Flip card',
            icon: Icons.flip_rounded,
            style: CustomButtonStyle.secondary,
            onPressed: onFlip,
          ),
        ],
      ),
    );
  }
}

class _FlashcardBack extends StatelessWidget {
  const _FlashcardBack({required this.word});

  final LearningWord word;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('back'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                word.word,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (word.partOfSpeech.trim().isNotEmpty)
              _Pill(label: word.partOfSpeech),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          word.meaningVi,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (word.definitions.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...word.definitions.take(4).map((definition) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  if (definition.partOfSpeech.trim().isNotEmpty)
                    definition.partOfSpeech,
                  definition.meaningVi,
                ].join(': '),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            );
          }),
        ],
        if (word.exampleEn.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            word.exampleEn,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (word.exampleVi.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              word.exampleVi,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
        if (word.topic.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _Pill(label: word.topic),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'How well do you know this word?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
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
              question.displayedMeaning.isEmpty
                  ? question.word.meaningVi
                  : question.displayedMeaning,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: question.isCorrect == null,
            textInputAction: TextInputAction.done,
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
  const _ChooseMeaningQuestion({
    required this.question,
    required this.onSelectOption,
  });

  final LearningQuestion question;
  final ValueChanged<String> onSelectOption;

  @override
  Widget build(BuildContext context) {
    final word = question.word;

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
            word.word,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (word.partOfSpeech.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(word.partOfSpeech),
          ],
          const SizedBox(height: 18),
          ...question.options.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionButton(
                question: question,
                option: option,
                onSelectOption: onSelectOption,
              ),
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
    final word = question.word;
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
            word.word,
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
            child: Text(
              question.displayedMeaning.isEmpty
                  ? word.meaningVi
                  : question.displayedMeaning,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.question,
    required this.isAnswered,
    required this.isLast,
    required this.answerController,
    required this.onFlashcardLevel,
    required this.onSubmitInputAnswer,
    required this.onSelectOption,
    required this.onAnswerTrueFalse,
    required this.onNext,
  });

  final LearningQuestion question;
  final bool isAnswered;
  final bool isLast;
  final TextEditingController answerController;
  final ValueChanged<String> onFlashcardLevel;
  final ValueChanged<String> onSubmitInputAnswer;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<bool> onAnswerTrueFalse;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (isAnswered && question.type != LearningQuestionType.flashcard) {
      return CustomButton(
        label: isLast ? 'Finish' : 'Continue',
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
        onPressed: () => onSubmitInputAnswer(answerController.text),
      ),
      LearningQuestionType.chooseMeaning => const SizedBox.shrink(),
      LearningQuestionType.trueFalse => Row(
        children: [
          Expanded(
            child: CustomButton(
              label: 'True',
              icon: Icons.check_rounded,
              onPressed: () => onAnswerTrueFalse(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CustomButton(
              label: 'False',
              icon: Icons.close_rounded,
              style: CustomButtonStyle.secondary,
              onPressed: () => onAnswerTrueFalse(false),
            ),
          ),
        ],
      ),
    };
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.question,
    required this.option,
    required this.onSelectOption,
  });

  final LearningQuestion question;
  final String option;
  final ValueChanged<String> onSelectOption;

  @override
  Widget build(BuildContext context) {
    final isAnswered = question.isCorrect != null;
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
        onPressed: isAnswered ? null : () => onSelectOption(option),
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
