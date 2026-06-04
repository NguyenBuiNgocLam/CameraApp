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
    final colors = Theme.of(context).colorScheme;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Kết quả học')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
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
                    'Hoàn thành bài học',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total câu đã học',
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
              label: 'Học tiếp',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _startAgain(context, VocabularyLearningMode.all),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Ôn lỗi sai',
              icon: Icons.refresh_rounded,
              style: CustomButtonStyle.secondary,
              onPressed:
                  () => _startAgain(context, VocabularyLearningMode.wrongOnly),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Quay về Vocabulary',
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _ResultCard(label: 'Số câu đúng', value: '${provider.correctCount}'),
        _ResultCard(label: 'Số câu sai', value: '${provider.wrongCount}'),
        _ResultCard(label: 'Thông thạo', value: '${provider.masteredCount}'),
        _ResultCard(label: 'Nhớ tạm', value: '${provider.temporaryCount}'),
        _ResultCard(label: 'Chưa biết', value: '${provider.unknownCount}'),
      ],
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
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
