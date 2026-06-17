import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../system_vocabulary/models/system_vocabulary_set.dart';
import '../../system_vocabulary/providers/system_vocabulary_provider.dart';
import '../models/word_list.dart';
import '../providers/word_list_provider.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WordListProvider>().loadWordLists();
      context.read<SystemVocabularyProvider>().loadSets();
    });
  }

  Future<void> _createList() async {
    final result = await showDialog<_CreateListResult>(
      context: context,
      builder: (_) => const _CreateListDialog(),
    );
    if (!mounted || result == null) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.createList(result.name, result.description);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Word list created'
              : provider.errorMessage ?? 'Could not create word list',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordListProvider>();
    final systemProvider = context.watch<SystemVocabularyProvider>();
    final systemSets = systemProvider.sets;
    final totalItems = systemSets.length + provider.wordLists.length;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Vocabulary')),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: CustomButton(
              label: 'Create word list',
              icon: Icons.add_rounded,
              onPressed: _createList,
            ),
          ),
          Expanded(
            child:
                provider.isLoading && totalItems == 0
                    ? const LoadingWidget(message: 'Loading word lists...')
                    : provider.errorMessage != null
                    ? ErrorStateWidget(
                      title: 'Could not load word lists',
                      message: provider.errorMessage!,
                      onRetry: provider.loadWordLists,
                    )
                    : totalItems == 0
                    ? const EmptyStateWidget(
                      title: 'No word lists yet',
                      message:
                          'Create your own list or import system vocabulary to get started.',
                      icon: Icons.folder_copy_rounded,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: totalItems,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index < systemSets.length) {
                          final set = systemSets[index];
                          return _SystemWordListCard(
                            set: set,
                            onTap: () async {
                              await systemProvider.selectSet(set);
                              if (!context.mounted) return;
                              Navigator.pushNamed(
                                context,
                                AppRoutes.systemVocabularyDetail,
                                arguments: set,
                              );
                            },
                          );
                        }

                        final userListIndex = index - systemSets.length;
                        final list = provider.wordLists[userListIndex];
                        return _WordListCard(
                          list: list,
                          onTap: () {
                            provider.selectList(list);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.wordListDetail,
                              arguments: list,
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _SystemWordListCard extends StatelessWidget {
  const _SystemWordListCard({required this.set, required this.onTap});

  final SystemVocabularySet set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.public_rounded, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        set.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'System',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  set.description.trim().isEmpty
                      ? 'Built-in vocabulary for everyone'
                      : set.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${set.totalWords} words',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _WordListCard extends StatelessWidget {
  const _WordListCard({required this.list, required this.onTap});

  final WordList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.folder_rounded, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  list.description.trim().isEmpty
                      ? 'No notes'
                      : list.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${list.wordCount} words',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _CreateListDialog extends StatefulWidget {
  const _CreateListDialog();

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create word list'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'List name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _CreateListResult(
                name: name,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateListResult {
  const _CreateListResult({required this.name, required this.description});

  final String name;
  final String description;
}
