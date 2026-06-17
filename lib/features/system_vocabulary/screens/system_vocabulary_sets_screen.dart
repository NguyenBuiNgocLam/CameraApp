import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/system_vocabulary_set.dart';
import '../providers/system_vocabulary_provider.dart';

class SystemVocabularySetsScreen extends StatefulWidget {
  const SystemVocabularySetsScreen({super.key});

  @override
  State<SystemVocabularySetsScreen> createState() =>
      _SystemVocabularySetsScreenState();
}

class _SystemVocabularySetsScreenState
    extends State<SystemVocabularySetsScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future.microtask(context.read<SystemVocabularyProvider>().loadSets);
  }

  Future<void> _openSet(SystemVocabularySet set) async {
    await context.read<SystemVocabularyProvider>().selectSet(set);
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.systemVocabularyDetail,
      arguments: set,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemVocabularyProvider>();

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('System Vocabulary')),
      child:
          provider.isLoading && provider.sets.isEmpty
              ? const LoadingWidget(message: 'Loading system vocabulary...')
              : provider.errorMessage != null && provider.sets.isEmpty
              ? ErrorStateWidget(
                title: 'Cannot load system vocabulary',
                message: provider.errorMessage!,
                onRetry: context.read<SystemVocabularyProvider>().loadSets,
              )
              : provider.sets.isEmpty
              ? const EmptyStateWidget(
                title: 'No system vocabulary yet',
                message: 'Import TOEIC 600 into Firestore to get started.',
                icon: Icons.public_rounded,
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                itemCount: provider.sets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final set = provider.sets[index];
                  return _SystemVocabularySetCard(
                    set: set,
                    masteredCount:
                        provider.selectedSet?.id == set.id
                            ? provider.masteredCount
                            : null,
                    onOpen: () => _openSet(set),
                  );
                },
              ),
    );
  }
}

class _SystemVocabularySetCard extends StatelessWidget {
  const _SystemVocabularySetCard({
    required this.set,
    required this.onOpen,
    this.masteredCount,
  });

  final SystemVocabularySet set;
  final VoidCallback onOpen;
  final int? masteredCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.public_rounded,
                  color: colors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      set.description,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.menu_book_rounded,
                label: '${set.totalWords} words',
              ),
              if (masteredCount != null)
                _InfoChip(
                  icon: Icons.verified_rounded,
                  label: '$masteredCount mastered',
                ),
              if (set.sourceStyle.trim().isNotEmpty)
                _InfoChip(icon: Icons.source_rounded, label: set.sourceStyle),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Start Learning',
                  icon: Icons.school_rounded,
                  onPressed: onOpen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  label: 'View Words',
                  icon: Icons.list_rounded,
                  style: CustomButtonStyle.secondary,
                  onPressed: onOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
