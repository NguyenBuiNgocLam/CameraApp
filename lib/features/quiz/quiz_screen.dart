import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/vocabulary_provider.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final vocabulary = context.read<VocabularyProvider>();
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null && vocabulary.items.isEmpty) {
      final quiz = context.read<QuizProvider>();
      Future.microtask(() async {
        await vocabulary.load();
        if (!mounted) return;
        quiz.start(vocabulary.items);
      });
    } else {
      final quiz = context.read<QuizProvider>();
      Future.microtask(() => quiz.start(vocabulary.items));
    }
  }

  Future<void> _next(BuildContext context) async {
    final quiz = context.read<QuizProvider>();
    if (quiz.next()) return;

    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null || userId.isEmpty) return;
    await quiz.saveResult(userId);
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.quizResult,
      arguments: quiz.score,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final quiz = context.watch<QuizProvider>();
    final question = quiz.currentQuestion;

    return MainScaffold(
      currentIndex: 3,
      appBar: AppBar(title: const Text('Practice Quiz')),
      child:
          question == null
              ? EmptyStateWidget(
                title: 'Not enough words',
                message:
                    quiz.errorMessage ??
                    'Save at least 4 vocabulary words before starting a quiz.',
                icon: Icons.quiz_rounded,
              )
              : LayoutBuilder(
                builder: (context, constraints) {
                  final total = quiz.totalQuestions;
                  final progress = (quiz.currentIndex + 1) / total;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Question ${quiz.currentIndex + 1}/$total',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 10,
                              child: LinearProgressIndicator(value: progress),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AppCard(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              question.question,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 18),
                          ...List.generate(
                            question.options.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AnswerOption(
                                label: question.options[index],
                                isSelected: quiz.selectedIndex == index,
                                isCorrect: index == question.correctIndex,
                                hasAnswered: quiz.selectedIndex != null,
                                onTap: () => quiz.select(index),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            label:
                                quiz.currentIndex == total - 1
                                    ? 'Finish Quiz'
                                    : 'Next',
                            icon:
                                quiz.currentIndex == total - 1
                                    ? Icons.flag_rounded
                                    : Icons.arrow_forward_rounded,
                            onPressed:
                                quiz.selectedIndex == null
                                    ? null
                                    : () => _next(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current score: ${quiz.score}/$total',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.hasAnswered,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool hasAnswered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color border = colors.outlineVariant;
    Color background = colors.surface;
    IconData? icon;

    if (hasAnswered && isCorrect) {
      border = AppColors.success;
      background = AppColors.success.withValues(alpha: 0.12);
      icon = Icons.check_circle_rounded;
    } else if (hasAnswered && isSelected && !isCorrect) {
      border = AppColors.error;
      background = AppColors.error.withValues(alpha: 0.12);
      icon = Icons.cancel_rounded;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (icon != null) Icon(icon, color: border),
          ],
        ),
      ),
    );
  }
}
