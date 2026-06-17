import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../providers/vocabulary_provider.dart';
import '../models/system_vocabulary_item.dart';
import '../models/system_vocabulary_progress.dart';
import '../models/system_vocabulary_set.dart';
import '../providers/system_vocabulary_provider.dart';

class SystemVocabularyDetailScreen extends StatefulWidget {
  const SystemVocabularyDetailScreen({required this.set, super.key});

  final SystemVocabularySet set;

  @override
  State<SystemVocabularyDetailScreen> createState() =>
      _SystemVocabularyDetailScreenState();
}

class _SystemVocabularyDetailScreenState
    extends State<SystemVocabularyDetailScreen> {
  bool _loaded = false;
  final _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<SystemVocabularyProvider>().selectSet(widget.set);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startLearning({required bool todayReviewOnly}) async {
    final provider = context.read<SystemVocabularyProvider>();
    await provider.startLearningSet(todayReviewOnly: todayReviewOnly);
    if (!mounted) return;

    if (provider.questions.isEmpty) {
      if (todayReviewOnly) {
        await _showNoReviewDialog(provider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'No words available for this session.',
            ),
          ),
        );
      }
      return;
    }

    Navigator.pushNamed(context, AppRoutes.systemVocabularyLearning);
  }

  Future<void> _showNoReviewDialog(SystemVocabularyProvider provider) async {
    final hasProgress = provider.progressMap.isNotEmpty;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              hasProgress
                  ? 'No review words for today'
                  : 'You don\'t have any words to review yet',
            ),
            content: Text(
              hasProgress
                  ? 'Come back tomorrow or learn new words now.'
                  : 'Start learning first, then your review schedule will appear here.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startLearning(todayReviewOnly: false);
                },
                icon: const Icon(Icons.school_rounded),
                label: const Text('Learn New Words'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final words = provider.filteredWords;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: Text(widget.set.name)),
      child:
          provider.isLoading && provider.words.isEmpty
              ? const LoadingWidget(message: 'Loading TOEIC words...')
              : provider.errorMessage != null && provider.words.isEmpty
              ? ErrorStateWidget(
                title: 'Cannot load TOEIC words',
                message: provider.errorMessage!,
                onRetry: provider.refresh,
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      children: [
                        _SystemLearningHeader(
                          provider: provider,
                          onLearn: () => _startLearning(todayReviewOnly: false),
                          onReview:
                              provider.dueTodayCount == 0
                                  ? null
                                  : () => _startLearning(todayReviewOnly: true),
                        ),
                        const SizedBox(height: 12),
                        _SystemVocabularyControls(
                          searchController: _searchController,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        words.isEmpty
                            ? const EmptyStateWidget(
                              title: 'No words found',
                              message:
                                  'Try changing your search, topic, or filter.',
                              icon: Icons.search_off_rounded,
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: words.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final word = words[index];
                                return _SystemVocabularyWordCard(word: word);
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}

class _SystemLearningHeader extends StatelessWidget {
  const _SystemLearningHeader({
    required this.provider,
    required this.onLearn,
    required this.onReview,
  });

  final SystemVocabularyProvider provider;
  final VoidCallback onLearn;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = provider.words.length;
    final learned = provider.learnedCount;
    final progress = total == 0 ? 0.0 : learned / total;
    final dueToday = provider.dueTodayCount;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.public_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$learned/$total learned',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CompactStatChip(
                  icon: Icons.menu_book_rounded,
                  label: '$total words',
                ),
                _CompactStatChip(
                  icon: Icons.verified_rounded,
                  label: '${provider.masteredCount} mastered',
                ),
                _CompactStatChip(
                  icon: Icons.psychology_alt_rounded,
                  label: '${provider.temporaryCount} learning',
                ),
                _CompactStatChip(
                  icon: Icons.today_rounded,
                  label: '$dueToday due today',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Learn',
                  icon: Icons.school_rounded,
                  onPressed: onLearn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  label: dueToday > 0 ? 'Review $dueToday' : 'Review',
                  icon: Icons.today_rounded,
                  style: CustomButtonStyle.secondary,
                  onPressed: onReview,
                ),
              ),
            ],
          ),
          if (dueToday == 0) ...[
            const SizedBox(height: 8),
            Text(
              'No words to review today',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactStatChip extends StatelessWidget {
  const _CompactStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({required this.provider});

  final SystemVocabularyProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = provider.selectedTopic ?? 'All topics';

    return PopupMenuButton<String?>(
      onSelected: provider.selectTopic,
      itemBuilder:
          (context) => [
            const PopupMenuItem<String?>(
              value: null,
              child: Text('All topics'),
            ),
            ...provider.topics.map(
              (topic) =>
                  PopupMenuItem<String?>(value: topic, child: Text(topic)),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline.withValues(alpha: 0.25)),
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.topic_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SystemVocabularyControls extends StatelessWidget {
  const _SystemVocabularyControls({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: provider.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search word or meaning...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon:
                  provider.searchQuery.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          provider.updateSearchQuery('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TopicButton(provider: provider),
                const SizedBox(width: 8),
                ...SystemVocabularyFilter.values.map((filter) {
                  final selected = provider.selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: selected,
                      onSelected: (_) => provider.selectFilter(filter),
                      selectedColor: colors.primary,
                      checkmarkColor: colors.onPrimary,
                      backgroundColor: colors.primary.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemVocabularyWordCard extends StatelessWidget {
  const _SystemVocabularyWordCard({required this.word});

  final SystemVocabularyItem word;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();
    final progress = provider.progressFor(word);
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Text(
              '${word.no}',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(word.meaningVi),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SmallBadge(label: word.partOfSpeech),
                    _SmallBadge(label: word.topic),
                    _LearningBadge(progress: progress),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pronounce',
            onPressed:
                () => context.read<VocabularyProvider>().speak(word.word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            tooltip: 'Favorite',
            onPressed: () => provider.toggleFavorite(word),
            icon: Icon(
              progress?.isFavorite ?? false
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            color:
                progress?.isFavorite ?? false
                    ? Colors.pinkAccent
                    : colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _LearningBadge extends StatelessWidget {
  const _LearningBadge({required this.progress});

  final SystemVocabularyProgress? progress;

  @override
  Widget build(BuildContext context) {
    final level = progress?.learningLevel.trim().toLowerCase() ?? 'unknown';
    final label = switch (level) {
      'mastered' => 'Mastered',
      'temporary' => 'Temporary',
      _ => 'Unknown',
    };
    final color = switch (level) {
      'mastered' => Colors.green,
      'temporary' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return _SmallBadge(label: label, color: color);
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).colorScheme.primary;
    final badgeColor = color ?? fallback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? 'Other' : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
