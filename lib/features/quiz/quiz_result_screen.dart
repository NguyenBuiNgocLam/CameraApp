import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/quiz_provider.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final providerTotal = context.watch<QuizProvider>().totalQuestions;
    final total = providerTotal == 0 ? 5 : providerTotal;
    final wrong = total - score;
    final message =
        score >= 4
            ? 'Great work! Your vocabulary is getting stronger.'
            : 'Good start! Review your saved words and try again.';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Result')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.success.withValues(
                              alpha: 0.14,
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.warning,
                              size: 46,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '$score/$total',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            child: _ResultStat(
                              title: 'Correct answers',
                              value: '$score',
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppCard(
                            child: _ResultStat(
                              title: 'Wrong answers',
                              value: '$wrong',
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    CustomButton(
                      label: 'Try Again',
                      icon: Icons.refresh_rounded,
                      onPressed:
                          () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.quiz,
                          ),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Back Home',
                      icon: Icons.home_rounded,
                      style: CustomButtonStyle.outline,
                      onPressed:
                          () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.home,
                            (_) => false,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
