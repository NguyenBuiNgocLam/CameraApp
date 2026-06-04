import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../core/widgets/vocabulary_card.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import 'widgets/add_vocabulary_dialog.dart';
import 'widgets/import_csv_dialog.dart';

enum _AddVocabularyAction { manual, csv }

class MyVocabularyScreen extends StatefulWidget {
  const MyVocabularyScreen({super.key});

  @override
  State<MyVocabularyScreen> createState() => _MyVocabularyScreenState();
}

class _MyVocabularyScreenState extends State<MyVocabularyScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final vocabulary = context.read<VocabularyProvider>();
    Future.microtask(vocabulary.load);
  }

  List<VocabularyItem> _filteredItems(List<VocabularyItem> source) {
    final query = _searchController.text.trim().toLowerCase();
    var items = source;

    if (_filter == 'Favorites') {
      items = items.where((item) => item.isFavorite).toList();
    } else if (_filter == 'Recent') {
      items = items.take(3).toList();
    }

    if (query.isEmpty) return items;
    return items
        .where(
          (item) =>
              item.word.toLowerCase().contains(query) ||
              item.meaningVi.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _openAddVocabularyDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const AddVocabularyDialog(),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
  }

  Future<void> _openImportCsvDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const ImportCsvDialog(),
    );
  }

  void _handleAddMenu(_AddVocabularyAction action) {
    switch (action) {
      case _AddVocabularyAction.manual:
        _openAddVocabularyDialog();
        break;
      case _AddVocabularyAction.csv:
        _openImportCsvDialog();
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = context.watch<VocabularyProvider>();
    final items = _filteredItems(vocabulary.items);
    final hasSavedWords = vocabulary.items.isNotEmpty;

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('My Vocabulary')),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                CustomTextField(
                  label: 'Search words',
                  prefixIcon: Icons.search_rounded,
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              ['All', 'Favorites', 'Recent']
                                  .map(
                                    (filter) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(filter),
                                        selected: _filter == filter,
                                        onSelected:
                                            (_) => setState(
                                              () => _filter = filter,
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<_AddVocabularyAction>(
                      tooltip: 'Thêm từ',
                      position: PopupMenuPosition.under,
                      onSelected: _handleAddMenu,
                      itemBuilder:
                          (context) => const [
                            PopupMenuItem(
                              value: _AddVocabularyAction.manual,
                              child: ListTile(
                                leading: Icon(Icons.edit_note_rounded),
                                title: Text('Thêm thủ công'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _AddVocabularyAction.csv,
                              child: ListTile(
                                leading: Icon(Icons.upload_file_rounded),
                                title: Text('Nhập từ CSV'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                      child: _AddWordButton(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        AppRoutes.vocabularyLearning,
                      ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.school_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Học từ vựng',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Bắt đầu học từ các từ đã lưu',
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
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
                    : items.isEmpty
                    ? _VocabularyEmptyState(hasSavedWords: hasSavedWords)
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

class _AddWordButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: colors.onPrimary, size: 20),
          const SizedBox(width: 6),
          Text(
            'Thêm từ',
            style: TextStyle(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, color: colors.onPrimary),
        ],
      ),
    );
  }
}

class _VocabularyEmptyState extends StatelessWidget {
  const _VocabularyEmptyState({required this.hasSavedWords});

  final bool hasSavedWords;

  @override
  Widget build(BuildContext context) {
    if (!hasSavedWords) {
      return const EmptyStateWidget(
        title: 'No saved words yet',
        message: 'Scan an image and save words to build your list.',
        icon: Icons.menu_book_rounded,
      );
    }

    return const EmptyStateWidget(
      title: 'No words found',
      message: 'Try another keyword or switch the filter back to All.',
      icon: Icons.search_off_rounded,
    );
  }
}
