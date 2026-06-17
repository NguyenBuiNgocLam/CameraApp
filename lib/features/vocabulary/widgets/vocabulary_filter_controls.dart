import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/vocabulary_provider.dart';
import '../models/vocabulary_filter.dart';

class VocabularyFilterControls extends StatefulWidget {
  const VocabularyFilterControls({super.key});

  @override
  State<VocabularyFilterControls> createState() =>
      _VocabularyFilterControlsState();
}

class _VocabularyFilterControlsState extends State<VocabularyFilterControls> {
  final _searchController = TextEditingController();
  bool _didSyncInitialQuery = false;

  static const _filters = [
    VocabularyFilter.all,
    VocabularyFilter.favorite,
    VocabularyFilter.unknown,
    VocabularyFilter.temporary,
    VocabularyFilter.mastered,
    VocabularyFilter.todayReview,
    VocabularyFilter.mostWrong,
    VocabularyFilter.noun,
    VocabularyFilter.verb,
    VocabularyFilter.adjective,
    VocabularyFilter.adverb,
    VocabularyFilter.phrase,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSyncInitialQuery) return;
    _didSyncInitialQuery = true;
    _searchController.text = context.read<VocabularyProvider>().searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: provider.updateSearchQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search vocabulary...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                provider.searchQuery.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
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
            children:
                _filters.map((filter) {
                  final selected = provider.selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: selected,
                      onSelected: (_) => provider.updateFilter(filter),
                      selectedColor: colors.primary,
                      checkmarkColor: colors.onPrimary,
                      backgroundColor: colors.primary.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color:
                            selected
                                ? colors.primary
                                : colors.outline.withValues(alpha: 0.28),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<VocabularySort>(
                value: provider.selectedSort,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  prefixIcon: Icon(Icons.sort_rounded),
                ),
                items:
                    VocabularySort.values
                        .map(
                          (sort) => DropdownMenuItem(
                            value: sort,
                            child: Text(sort.label),
                          ),
                        )
                        .toList(),
                onChanged: (sort) {
                  if (sort == null) return;
                  provider.updateSort(sort);
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Clear filters',
              onPressed: () {
                _searchController.clear();
                provider.clearFilters();
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
