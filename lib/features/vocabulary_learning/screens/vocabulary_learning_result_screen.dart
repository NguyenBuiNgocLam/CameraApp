import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../providers/vocabulary_learning_provider.dart';

class VocabularyLearningResultScreen extends StatelessWidget {
  const VocabularyLearningResultScreen({super.key});

  Future<void> _startAgain(
    BuildContext context,
    VocabularyLearningMode mode,
  ) async {
    final provider = context.read<VocabularyLearningProvider>();
    await provider.startLearning(mode: mode);
    if (!context.mounted) return;

    if (provider.questions.isEmpty) {
      Navigator.pushReplacementNamed(context, AppRoutes.vocabularyLearning);
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.vocabularyLearningPractice,
    );
  }

  void _backToVocabulary(BuildContext context) {
    context.read<VocabularyLearningProvider>().resetLearning();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.vocabulary,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyLearningProvider>();
    final total = provider.questions.length;
    final isReview =
        provider.sessionMode == VocabularyLearningSessionMode.review;
    final colors = Theme.of(context).colorScheme;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(
        title: Text(isReview ? 'Review Results' : 'Learning Results'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: colors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isReview ? 'Review completed' : 'Lesson completed',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total questions studied',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ResultGrid(provider: provider),
            const SizedBox(height: 18),
            CustomButton(
              label: 'Continue learning',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _startAgain(context, VocabularyLearningMode.all),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Review due words',
              icon: Icons.refresh_rounded,
              style: CustomButtonStyle.secondary,
              onPressed:
                  () => provider.startTodayReview().then((_) {
                    if (!context.mounted) return;
                    if (provider.questions.isEmpty) {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.vocabularyLearning,
                      );
                      return;
                    }
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.vocabularyLearningPractice,
                    );
                  }),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Back to Vocabulary',
              icon: Icons.menu_book_rounded,
              style: CustomButtonStyle.outline,
              onPressed: () => _backToVocabulary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.provider});

  final VocabularyLearningProvider provider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final crossAxisCount = isNarrow ? 1 : 2;
        const spacing = 12.0;
        const desiredHeight = 112.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: itemWidth / desiredHeight,
          children: [
            _ResultCard(
              label: 'Correct answers',
              value: '${provider.correctCount}',
            ),
            _ResultCard(
              label: 'Wrong answers',
              value: '${provider.wrongCount}',
            ),
            _ResultCard(label: 'Mastered', value: '${provider.masteredCount}'),
            _ResultCard(label: 'Learning', value: '${provider.temporaryCount}'),
            _ResultCard(label: 'Unknown', value: '${provider.unknownCount}'),
          ],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
