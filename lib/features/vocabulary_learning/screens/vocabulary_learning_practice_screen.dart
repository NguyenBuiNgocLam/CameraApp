import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../models/vocabulary_item.dart';
import '../models/learning_question.dart';
import '../providers/vocabulary_learning_provider.dart';

class VocabularyLearningPracticeScreen extends StatefulWidget {
  const VocabularyLearningPracticeScreen({super.key});

  @override
  State<VocabularyLearningPracticeScreen> createState() =>
      _VocabularyLearningPracticeScreenState();
}

class _VocabularyLearningPracticeScreenState
    extends State<VocabularyLearningPracticeScreen> {
  final _inputController = TextEditingController();
  String? _flippedQuestionId;
  String? _questionId;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool _isFlipped(String questionId) => _flippedQuestionId == questionId;

  void _toggleFlip(String questionId) {
    setState(() {
      _flippedQuestionId = _flippedQuestionId == questionId ? null : questionId;
    });
  }

  void _goNext(VocabularyLearningProvider provider) {
    setState(() => _flippedQuestionId = null);
    provider.goNext();
    if (provider.isFinished && mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.vocabularyLearningResult,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyLearningProvider>();
    final question = provider.currentQuestion;

    if (question == null) {
      return MainScaffold(
        currentIndex: 2,
        appBar: AppBar(title: const Text('Học từ vựng')),
        child: const EmptyStateWidget(
          title: 'Chưa có bài học',
          message: 'Hãy bắt đầu học từ màn Vocabulary Learning.',
          icon: Icons.school_rounded,
        ),
      );
    }

    if (_questionId != question.id) {
      _questionId = question.id;
      _flippedQuestionId = null;
      _inputController.clear();
    }

    final progress = (provider.currentIndex + 1) / provider.questions.length;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Học từ vựng')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressHeader(
              progress: progress,
              current: provider.currentIndex + 1,
              total: provider.questions.length,
              title: _questionTitle(question.type),
            ),
            const SizedBox(height: 16),
            if (question.type == LearningQuestionType.flashcard)
              _FlashcardPractice(
                item: question.vocabularyItem,
                isFlipped: _isFlipped(question.id),
                isAnswered: provider.isAnswered,
                onFlip: () => _toggleFlip(question.id),
                onSpeak: provider.speakCurrentWord,
                onLevel: provider.answerFlashcardLevel,
              )
            else if (question.type == LearningQuestionType.inputWord)
              _InputWordPractice(
                question: question,
                controller: _inputController,
                isAnswered: provider.isAnswered,
                isCorrect: provider.lastAnswerCorrect,
                onSubmit:
                    () => provider.submitInputAnswer(_inputController.text),
              )
            else if (question.type == LearningQuestionType.chooseMeaning)
              _ChooseMeaningPractice(
                question: question,
                isAnswered: provider.isAnswered,
                onSelect: provider.selectOption,
              )
            else if (question.type == LearningQuestionType.trueFalse)
              _TrueFalsePractice(
                question: question,
                isAnswered: provider.isAnswered,
                isCorrect: provider.lastAnswerCorrect,
                onAnswer: provider.answerTrueFalse,
              )
            else
              _ComingSoonQuestion(question: question),
            const SizedBox(height: 18),
            if (provider.isAnswered)
              CustomButton(
                label:
                    provider.currentIndex >= provider.questions.length - 1
                        ? 'Hoàn thành'
                        : 'Tiếp tục',
                icon: Icons.chevron_right_rounded,
                onPressed: () => _goNext(provider),
              ),
          ],
        ),
      ),
    );
  }

  String _questionTitle(LearningQuestionType type) {
    return switch (type) {
      LearningQuestionType.flashcard => 'Từ mới',
      LearningQuestionType.inputWord => 'Nhập từ',
      LearningQuestionType.chooseMeaning => 'Chọn nghĩa',
      LearningQuestionType.trueFalse => 'Đúng hay sai',
    };
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.current,
    required this.total,
    required this.title,
  });

  final double progress;
  final int current;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: colors.primary.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '$current/$total',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlashcardPractice extends StatelessWidget {
  const _FlashcardPractice({
    required this.item,
    required this.isFlipped,
    required this.isAnswered,
    required this.onFlip,
    required this.onSpeak,
    required this.onLevel,
  });

  final VocabularyItem item;
  final bool isFlipped;
  final bool isAnswered;
  final VoidCallback onFlip;
  final VoidCallback onSpeak;
  final Future<void> Function(String level) onLevel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child:
          isFlipped
              ? _FlashcardBack(
                item: item,
                isAnswered: isAnswered,
                onFlip: onFlip,
                onLevel: onLevel,
              )
              : _FlashcardFront(item: item, onFlip: onFlip, onSpeak: onSpeak),
    );
  }
}

class _FlashcardFront extends StatelessWidget {
  const _FlashcardFront({
    required this.item,
    required this.onFlip,
    required this.onSpeak,
  });

  final VocabularyItem item;
  final VoidCallback onFlip;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: colors.primary.withValues(alpha: 0.12),
          child: Icon(Icons.style_rounded, color: colors.primary, size: 34),
        ),
        const SizedBox(height: 22),
        Text(
          item.word,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (item.phonetic.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.phonetic,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        IconButton.filledTonal(
          tooltip: 'Phát âm',
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up_rounded),
        ),
        const SizedBox(height: 24),
        CustomButton(label: 'Lật', icon: Icons.flip_rounded, onPressed: onFlip),
      ],
    );
  }
}

class _FlashcardBack extends StatelessWidget {
  const _FlashcardBack({
    required this.item,
    required this.isAnswered,
    required this.onFlip,
    required this.onLevel,
  });

  final VocabularyItem item;
  final bool isAnswered;
  final VoidCallback onFlip;
  final Future<void> Function(String level) onLevel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final definitions = item.effectiveDefinitions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((item.imageUrl ?? '').trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              item.imageUrl!,
              height: 170,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    height: 120,
                    color: colors.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded),
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                item.word,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (item.partOfSpeech.trim().isNotEmpty)
              Chip(label: Text(item.partOfSpeech)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.meaningVi,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (definitions.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...definitions.map(
            (definition) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  if (definition.partOfSpeech.trim().isNotEmpty)
                    definition.partOfSpeech,
                  definition.meaningVi,
                ].join(': '),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
        if (item.exampleEn.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            item.exampleEn,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (item.exampleVi.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.exampleVi,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: onFlip,
          icon: const Icon(Icons.flip_rounded),
          label: const Text('Xem mặt trước'),
        ),
        const SizedBox(height: 18),
        Text(
          'Bạn thuộc từ này ở mức nào?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: isAnswered ? null : () => onLevel('mastered'),
              child: const Text('Thông thạo'),
            ),
            FilledButton.tonal(
              onPressed: isAnswered ? null : () => onLevel('temporary'),
              child: const Text('Nhớ tạm'),
            ),
            OutlinedButton(
              onPressed: isAnswered ? null : () => onLevel('unknown'),
              child: const Text('Chưa biết'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InputWordPractice extends StatelessWidget {
  const _InputWordPractice({
    required this.question,
    required this.controller,
    required this.isAnswered,
    required this.isCorrect,
    required this.onSubmit,
  });

  final LearningQuestion question;
  final TextEditingController controller;
  final bool isAnswered;
  final bool? isCorrect;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final item = question.vocabularyItem;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nhập từ tiếng Anh tương ứng với nghĩa:',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.meaningVi,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (item.effectiveDefinitions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...item.effectiveDefinitions
                .take(3)
                .map(
                  (definition) => Text(
                    definition.meaningVi,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            enabled: !isAnswered,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isAnswered) onSubmit();
            },
            decoration: InputDecoration(
              labelText: 'Từ tiếng Anh',
              suffixIcon:
                  isAnswered
                      ? Icon(
                        isCorrect == true
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isCorrect == true ? Colors.green : colors.error,
                      )
                      : null,
            ),
          ),
          if (isAnswered) ...[
            const SizedBox(height: 14),
            _AnswerFeedback(
              isCorrect: isCorrect == true,
              message:
                  isCorrect == true
                      ? 'Chính xác!'
                      : 'Đáp án đúng: ${question.correctAnswer}',
            ),
            _WordInfo(item: item),
          ],
          const SizedBox(height: 18),
          CustomButton(
            label: 'Kiểm tra',
            icon: Icons.fact_check_rounded,
            onPressed: isAnswered ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ChooseMeaningPractice extends StatelessWidget {
  const _ChooseMeaningPractice({
    required this.question,
    required this.isAnswered,
    required this.onSelect,
  });

  final LearningQuestion question;
  final bool isAnswered;
  final Future<void> Function(String option) onSelect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chọn nghĩa đúng của từ:',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question.vocabularyItem.word,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (question.vocabularyItem.phonetic.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              question.vocabularyItem.phonetic,
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
          const SizedBox(height: 20),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionButton(
                label: option,
                isAnswered: isAnswered,
                isSelected: question.userAnswer == option,
                isCorrect: option == question.correctAnswer,
                onPressed: () => onSelect(option),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrueFalsePractice extends StatelessWidget {
  const _TrueFalsePractice({
    required this.question,
    required this.isAnswered,
    required this.isCorrect,
    required this.onAnswer,
  });

  final LearningQuestion question;
  final bool isAnswered;
  final bool? isCorrect;
  final Future<void> Function(bool value) onAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expectedTrue = question.correctAnswer == 'true';

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.vocabularyItem.word,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'Có nghĩa là',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _TrueFalseButton(
                  label: 'Đúng',
                  value: true,
                  isAnswered: isAnswered,
                  isCorrectOption: expectedTrue,
                  userAnswer: question.userAnswer,
                  onPressed: () => onAnswer(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrueFalseButton(
                  label: 'Sai',
                  value: false,
                  isAnswered: isAnswered,
                  isCorrectOption: !expectedTrue,
                  userAnswer: question.userAnswer,
                  onPressed: () => onAnswer(false),
                ),
              ),
            ],
          ),
          if (isAnswered) ...[
            const SizedBox(height: 14),
            _AnswerFeedback(
              isCorrect: isCorrect == true,
              message:
                  isCorrect == true
                      ? 'Chính xác!'
                      : 'Đáp án đúng: ${expectedTrue ? 'Đúng' : 'Sai'}',
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.isAnswered,
    required this.isSelected,
    required this.isCorrect,
    required this.onPressed,
  });

  final String label;
  final bool isAnswered;
  final bool isSelected;
  final bool isCorrect;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        !isAnswered
            ? colors.surface
            : isCorrect
            ? Colors.green.withValues(alpha: 0.16)
            : isSelected
            ? colors.error.withValues(alpha: 0.14)
            : colors.surface;
    final foreground =
        !isAnswered
            ? colors.onSurface
            : isCorrect
            ? Colors.green.shade700
            : isSelected
            ? colors.error
            : colors.onSurface;
    final borderColor =
        !isAnswered
            ? colors.outlineVariant
            : isCorrect
            ? Colors.green
            : isSelected
            ? colors.error
            : colors.outlineVariant;

    return OutlinedButton(
      onPressed: isAnswered ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        side: BorderSide(color: borderColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _TrueFalseButton extends StatelessWidget {
  const _TrueFalseButton({
    required this.label,
    required this.value,
    required this.isAnswered,
    required this.isCorrectOption,
    required this.userAnswer,
    required this.onPressed,
  });

  final String label;
  final bool value;
  final bool isAnswered;
  final bool isCorrectOption;
  final String? userAnswer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = userAnswer == value.toString();
    final colors = Theme.of(context).colorScheme;
    final background =
        !isAnswered
            ? colors.surface
            : isCorrectOption
            ? Colors.green.withValues(alpha: 0.16)
            : selected
            ? colors.error.withValues(alpha: 0.14)
            : colors.surface;
    final foreground =
        !isAnswered
            ? colors.onSurface
            : isCorrectOption
            ? Colors.green.shade700
            : selected
            ? colors.error
            : colors.onSurfaceVariant;

    return OutlinedButton(
      onPressed: isAnswered ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.isCorrect, required this.message});

  final bool isCorrect;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isCorrect
                ? Colors.green.withValues(alpha: 0.14)
                : colors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isCorrect ? Colors.green.shade700 : colors.error,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WordInfo extends StatelessWidget {
  const _WordInfo({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.phonetic.trim().isNotEmpty)
            Text(item.phonetic, style: TextStyle(color: colors.secondary)),
          if (item.partOfSpeech.trim().isNotEmpty)
            Text(
              item.partOfSpeech,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          if (item.exampleEn.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.exampleEn,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComingSoonQuestion extends StatelessWidget {
  const _ComingSoonQuestion({required this.question});

  final LearningQuestion question;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Dạng bài này sẽ được hoàn thiện ở bước tiếp theo.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
