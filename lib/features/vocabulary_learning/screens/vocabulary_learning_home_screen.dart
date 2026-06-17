import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../vocabulary/providers/word_list_provider.dart';
import '../providers/vocabulary_learning_provider.dart';

class VocabularyLearningHomeScreen extends StatefulWidget {
  const VocabularyLearningHomeScreen({super.key});

  @override
  State<VocabularyLearningHomeScreen> createState() =>
      _VocabularyLearningHomeScreenState();
}

class _VocabularyLearningHomeScreenState
    extends State<VocabularyLearningHomeScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final wordLists = context.read<WordListProvider>();
    final learning = context.read<VocabularyLearningProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (wordLists.wordLists.isEmpty) await wordLists.loadWordLists();
      if (!mounted) return;
      final selectedList =
          wordLists.selectedList ?? wordLists.wordLists.firstOrNull;
      if (selectedList == null) return;
      await learning.loadWordListStats(selectedList.id);
    });
  }

  Future<void> _startPractice(VocabularyLearningMode mode) async {
    final provider = context.read<VocabularyLearningProvider>();
    final wordLists = context.read<WordListProvider>();
    final selectedList =
        wordLists.selectedList ?? wordLists.wordLists.firstOrNull;
    if (selectedList == null) return;
    await provider.startLearning(mode: mode, listId: selectedList.id);
    if (!mounted) return;
    if (provider.questions.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.vocabularyLearningPractice);
  }

  Future<void> _startReview() async {
    final provider = context.read<VocabularyLearningProvider>();
    final wordLists = context.read<WordListProvider>();
    final selectedList =
        wordLists.selectedList ?? wordLists.wordLists.firstOrNull;
    if (selectedList == null) return;
    await provider.startTodayReview(listId: selectedList.id);
    if (!mounted) return;
    if (provider.questions.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.vocabularyLearningPractice);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyLearningProvider>();
    final wordList = context.watch<WordListProvider>().selectedList;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Vocabulary Learning')),
      child:
          provider.isLoading
              ? const LoadingWidget(message: 'Loading vocabulary...')
              : wordList == null
              ? const EmptyStateWidget(
                title: 'No vocabulary yet',
                message: 'Add some words first, then come back to study.',
                icon: Icons.school_rounded,
              )
              : provider.errorMessage != null && provider.questions.isEmpty
              ? ErrorStateWidget(
                title: 'Cannot start learning yet',
                message: provider.errorMessage!,
                onRetry: () => provider.startLearning(),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      totalWords: provider.listTotalCount,
                      listName: wordList.name,
                    ),
                    const SizedBox(height: 14),
                    _StatsGrid(provider: provider),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Start learning',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          () => _startPractice(VocabularyLearningMode.all),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      label:
                          provider.dueTodayCount > 0
                              ? 'Review ${provider.dueTodayCount}'
                              : 'Review',
                      icon: Icons.today_rounded,
                      style: CustomButtonStyle.secondary,
                      isLoading: provider.isReviewLoading,
                      onPressed:
                          provider.dueTodayCount == 0 ? null : _startReview,
                    ),
                  ],
                ),
              ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.totalWords, required this.listName});

  final int totalWords;
  final String listName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.school_rounded, color: colors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vocabulary Learning',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '$listName · 10 flashcards + practice · $totalWords words ready',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.provider});

  final VocabularyLearningProvider provider;

  @override
  Widget build(BuildContext context) {
    final unknown = provider.listUnknownCount;
    final temporary = provider.listTemporaryCount;
    final mastered = provider.listMasteredCount;
    final wrong = provider.listWrongCount;
    final due = provider.dueTodayCount;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: [
        _StatCard(
          label: 'Total words',
          value: provider.listTotalCount.toString(),
        ),
        _StatCard(label: 'Unknown', value: unknown.toString()),
        _StatCard(label: 'Learning', value: temporary.toString()),
        _StatCard(label: 'Mastered', value: mastered.toString()),
        _StatCard(label: 'Previously wrong', value: wrong.toString()),
        _StatCard(label: 'Due today', value: due.toString()),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

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
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
