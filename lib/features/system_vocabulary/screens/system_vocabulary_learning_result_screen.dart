import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../providers/system_vocabulary_provider.dart';

class SystemVocabularyLearningResultScreen extends StatelessWidget {
  const SystemVocabularyLearningResultScreen({super.key});

  Future<void> _startAgain(
    BuildContext context, {
    required bool todayReviewOnly,
  }) async {
    final provider = context.read<SystemVocabularyProvider>();
    await provider.startLearningSet(todayReviewOnly: todayReviewOnly);
    if (!context.mounted) return;

    if (provider.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'No words available for this session.',
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.systemVocabularyLearning);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final flashcards = provider.sessionFlashcardCount;
    final practice = provider.sessionPracticeCount;
    final correct = provider.sessionCorrectCount;
    final wrong = provider.sessionWrongCount;
    final accuracy = practice == 0 ? 0 : ((correct / practice) * 100).round();
    final isReview = provider.sessionMode == LearningSessionMode.review;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(
        title: Text(isReview ? 'Review Result' : 'Learning Result'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isReview ? 'Review completed' : 'Session completed',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$accuracy% accuracy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final crossAxisCount = isNarrow ? 1 : 2;
              const spacing = 12.0;
              const desiredHeight = 118.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                childAspectRatio: itemWidth / desiredHeight,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ResultStat(
                    label: 'Words learned',
                    value: '${provider.learningWords.length}',
                    icon: Icons.menu_book_rounded,
                  ),
                  _ResultStat(
                    label: 'Flashcards',
                    value: '$flashcards',
                    icon: Icons.style_rounded,
                  ),
                  _ResultStat(
                    label: 'Practice',
                    value: '$practice',
                    icon: Icons.fact_check_rounded,
                  ),
                  _ResultStat(
                    label: 'Correct',
                    value: '$correct',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                  _ResultStat(
                    label: 'Wrong',
                    value: '$wrong',
                    icon: Icons.cancel_rounded,
                    color: Colors.redAccent,
                  ),
                  _ResultStat(
                    label: 'Mastered',
                    value: '${provider.sessionMasteredCount}',
                    icon: Icons.workspace_premium_rounded,
                    color: Colors.green,
                  ),
                  _ResultStat(
                    label: 'Temporary',
                    value: '${provider.sessionTemporaryCount}',
                    icon: Icons.psychology_alt_rounded,
                    color: Colors.orange,
                  ),
                  _ResultStat(
                    label: 'Unknown',
                    value: '${provider.sessionUnknownCount}',
                    icon: Icons.refresh_rounded,
                    color: Colors.orange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          CustomButton(
            label: 'Continue learning',
            icon: Icons.school_rounded,
            onPressed: () => _startAgain(context, todayReviewOnly: false),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: 'Review due words',
            icon: Icons.today_rounded,
            style: CustomButtonStyle.secondary,
            onPressed: () => _startAgain(context, todayReviewOnly: true),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: 'Back to System Vocabulary',
            icon: Icons.arrow_back_rounded,
            style: CustomButtonStyle.outline,
            onPressed: () {
              provider.resetLearningSession();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.systemVocabulary,
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statColor = color ?? colors.primary;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: statColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
