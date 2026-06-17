import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../core/widgets/vocabulary_card.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../vocabulary_learning/providers/vocabulary_learning_provider.dart';
import '../models/word_list.dart';
import '../providers/word_list_provider.dart';
import '../widgets/add_vocabulary_dialog.dart';
import '../widgets/import_csv_dialog.dart';
import '../widgets/vocabulary_filter_controls.dart';

class WordListDetailScreen extends StatefulWidget {
  const WordListDetailScreen({required this.list, super.key});

  final WordList list;

  @override
  State<WordListDetailScreen> createState() => _WordListDetailScreenState();
}

class _WordListDetailScreenState extends State<WordListDetailScreen> {
  bool _loaded = false;
  late WordList _list;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WordListProvider>().selectList(_list);
      context.read<VocabularyProvider>().load();
      context.read<VocabularyLearningProvider>().loadWordListStats(_list.id);
    });
  }

  List<VocabularyItem> _itemsForList(List<VocabularyItem> items) {
    return items.where((item) => item.listId == _list.id).toList();
  }

  Future<void> _openAddVocabularyDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddVocabularyDialog(initialListId: _list.id),
    );
    if (!mounted || saved != true) return;
    await context.read<WordListProvider>().refreshWordCount();
    if (!mounted) return;
    _syncCurrentList();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
  }

  Future<void> _openImportCsvDialog() async {
    final imported = await showDialog<bool>(
      context: context,
      builder: (_) => ImportCsvDialog(initialListId: _list.id),
    );
    if (!mounted || imported != true) return;
    await context.read<WordListProvider>().refreshWordCount();
    if (!mounted) return;
    _syncCurrentList();
  }

  Future<void> _openEditListDialog() async {
    final result = await showDialog<_EditListResult>(
      context: context,
      builder: (_) => _EditListDialog(list: _list),
    );
    if (!mounted || result == null) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.updateList(
      list: _list,
      name: result.name,
      description: result.description,
    );
    if (!mounted) return;

    if (success) {
      _syncCurrentList();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'List updated'
              : provider.errorMessage ?? 'Could not update list',
        ),
      ),
    );
  }

  Future<void> _deleteList(List<VocabularyItem> items) async {
    if (items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only empty lists can be deleted. Remove the words first.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete this list?'),
            content: Text('List "${_list.name}" is empty and will be deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.deleteList(_list);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'List deleted'
              : provider.errorMessage ?? 'Could not delete list',
        ),
      ),
    );
    if (success) {
      Navigator.pop(context);
    }
  }

  Future<void> _startLearning() async {
    final provider = context.read<VocabularyLearningProvider>();
    await provider.startLearning(listId: _list.id);
    if (!mounted) return;

    if (provider.unifiedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'This list has no words yet.'),
        ),
      );
      return;
    }

    await Navigator.pushNamed(context, AppRoutes.vocabularyLearningPractice);
    if (!mounted) return;
    await context.read<VocabularyProvider>().load();
    if (!mounted) return;
    await context.read<VocabularyLearningProvider>().loadWordListStats(
      _list.id,
    );
  }

  Future<void> _startReview() async {
    final provider = context.read<VocabularyLearningProvider>();
    await provider.startTodayReview(listId: _list.id);
    if (!mounted) return;

    if (provider.unifiedQuestions.isEmpty) {
      await _showNoReviewDialog();
      return;
    }

    await Navigator.pushNamed(context, AppRoutes.vocabularyLearningPractice);
    if (!mounted) return;
    await context.read<VocabularyProvider>().load();
    if (!mounted) return;
    await context.read<VocabularyLearningProvider>().loadWordListStats(
      _list.id,
    );
  }

  Future<void> _showNoReviewDialog() async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No words to review today'),
            content: const Text('Come back later or learn new words now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startLearning();
                },
                icon: const Icon(Icons.school_rounded),
                label: const Text('Learn New Words'),
              ),
            ],
          ),
    );
  }

  void _syncCurrentList() {
    final provider = context.read<WordListProvider>();
    final updated = provider.wordLists.where((list) => list.id == _list.id);
    if (updated.isEmpty) return;
    setState(() => _list = updated.first);
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = context.watch<VocabularyProvider>();
    final learning = context.watch<VocabularyLearningProvider>();
    final allListItems = _itemsForList(vocabulary.items);
    final items = vocabulary.filteredVocabularyForList(_list.id);
    final stats = _WordListLearningStats.fromItems(allListItems);

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'List options',
            onSelected: (value) {
              if (value == 'edit') {
                _openEditListDialog();
              } else if (value == 'delete') {
                _deleteList(allListItems);
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Edit list name'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete list'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Study',
                        icon: Icons.school_rounded,
                        isLoading: learning.isLoading,
                        onPressed: _startLearning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        label:
                            stats.dueToday > 0
                                ? 'Review ${stats.dueToday}'
                                : 'Review',
                        icon: Icons.today_rounded,
                        style: CustomButtonStyle.secondary,
                        isLoading: learning.isReviewLoading,
                        onPressed: stats.dueToday == 0 ? null : _startReview,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _LearningStatsCard(stats: stats),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Add word',
                        icon: Icons.add_rounded,
                        style: CustomButtonStyle.secondary,
                        onPressed: _openAddVocabularyDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        label: 'Import CSV',
                        icon: Icons.upload_file_rounded,
                        style: CustomButtonStyle.outline,
                        onPressed: _openImportCsvDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const VocabularyFilterControls(),
              ],
            ),
          ),
          Expanded(
            child:
                vocabulary.isLoading
                    ? const LoadingWidget(message: 'Loading vocabulary...')
                    : vocabulary.errorMessage != null
                    ? ErrorStateWidget(
                      title: 'Cannot load vocabulary',
                      message: vocabulary.errorMessage!,
                      onRetry: context.read<VocabularyProvider>().load,
                    )
                    : allListItems.isEmpty
                    ? const EmptyStateWidget(
                      title: 'This list has no words yet',
                      message:
                          'Add words manually or import a CSV to get started.',
                      icon: Icons.menu_book_rounded,
                    )
                    : items.isEmpty
                    ? const EmptyStateWidget(
                      title: 'No vocabulary found',
                      message: 'Try changing your search or filters.',
                      icon: Icons.search_off_rounded,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return VocabularyCard(
                          item: item,
                          showDelete: true,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                AppRoutes.vocabularyDetail,
                                arguments: item,
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _LearningStatsCard extends StatelessWidget {
  const _LearningStatsCard({required this.stats});

  final _WordListLearningStats stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatChip(
              icon: Icons.school_rounded,
              label: '${stats.learned}/${stats.total} learned',
            ),
            _StatChip(
              icon: Icons.verified_rounded,
              label: '${stats.mastered} mastered',
            ),
            _StatChip(
              icon: Icons.psychology_alt_rounded,
              label: '${stats.temporary} learning',
            ),
            _StatChip(
              icon: Icons.help_outline_rounded,
              label: '${stats.unknown} unknown',
            ),
            _StatChip(
              icon: Icons.today_rounded,
              label: '${stats.dueToday} due today',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

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

class _WordListLearningStats {
  const _WordListLearningStats({
    required this.total,
    required this.learned,
    required this.mastered,
    required this.temporary,
    required this.unknown,
    required this.dueToday,
  });

  final int total;
  final int learned;
  final int mastered;
  final int temporary;
  final int unknown;
  final int dueToday;

  factory _WordListLearningStats.fromItems(List<VocabularyItem> items) {
    final endOfToday = _endOfToday();
    return _WordListLearningStats(
      total: items.length,
      learned:
          items
              .where(
                (item) => item.hasSeenFlashcard || item.lastReviewedAt != null,
              )
              .length,
      mastered: items.where((item) => item.learningLevel == 'mastered').length,
      temporary:
          items.where((item) => item.learningLevel == 'temporary').length,
      unknown: items.where((item) => item.learningLevel == 'unknown').length,
      dueToday:
          items.where((item) {
            final nextReviewAt = item.nextReviewAt;
            final learned =
                item.hasSeenFlashcard || item.lastReviewedAt != null;
            return learned &&
                nextReviewAt != null &&
                !nextReviewAt.isAfter(endOfToday);
          }).length,
    );
  }

  static DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }
}

class _EditListDialog extends StatefulWidget {
  const _EditListDialog({required this.list});

  final WordList list;

  @override
  State<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends State<_EditListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
    _descriptionController = TextEditingController(
      text: widget.list.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit list'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
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
              _EditListResult(
                name: name,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditListResult {
  const _EditListResult({required this.name, required this.description});

  final String name;
  final String description;
}
