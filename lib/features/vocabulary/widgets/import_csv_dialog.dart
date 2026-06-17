import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../features/vocabulary/models/word_list.dart';
import '../../../features/vocabulary/providers/word_list_provider.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../services/csv_import_service.dart';

class ImportCsvDialog extends StatefulWidget {
  const ImportCsvDialog({this.initialListId, super.key});

  final String? initialListId;

  @override
  State<ImportCsvDialog> createState() => _ImportCsvDialogState();
}

class _ImportCsvDialogState extends State<ImportCsvDialog> {
  final _csvImportService = CsvImportService();
  List<VocabularyItem> _items = [];
  bool _isPicking = false;
  String? _message;
  bool _isError = false;
  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final wordLists = context.read<WordListProvider>();
      if (wordLists.wordLists.isEmpty) {
        await wordLists.loadWordLists();
      }
      if (!mounted) return;
      setState(() {
        _selectedListId ??= wordLists.selectedList?.id;
      });
    });
  }

  Future<void> _pickCsv() async {
    setState(() {
      _isPicking = true;
      _message = null;
      _isError = false;
    });

    try {
      final items = await _csvImportService.pickAndParseVocabularyCsv();
      if (!mounted) return;
      if (items == null) {
        setState(() {
          _message = 'You did not select a CSV file.';
          _isError = false;
          _isPicking = false;
        });
        return;
      }

      setState(() {
        _items = items;
        _message =
            'Loaded ${items.length} words. Review the preview before importing.';
        _isError = false;
        _isPicking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _isError = true;
        _isPicking = false;
      });
    }
  }

  Future<void> _importCsv() async {
    if (_items.isEmpty) return;
    final selectedListId = _selectedListId;
    if (selectedListId == null || selectedListId.trim().isEmpty) {
      setState(() {
        _message = 'Please select a word list.';
        _isError = true;
      });
      return;
    }
    final provider = context.read<VocabularyProvider>();
    final importedCount = await provider.importVocabularyFromCsv(
      _items.map((item) => item.copyWith(listId: selectedListId)).toList(),
    );
    if (!mounted) return;

    if (importedCount == 0 && provider.errorMessage != null) {
      setState(() {
        _message = provider.errorMessage;
        _isError = true;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported $importedCount/${_items.length} words successfully.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    final wordListProvider = context.watch<WordListProvider>();
    final colors = Theme.of(context).colorScheme;
    final previewItems = _items.take(6).toList();
    final wordLists = wordListProvider.wordLists;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Import from CSV',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Format: word, meaningVi, phonetic, partOfSpeech, exampleEn, exampleVi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _safeSelectedListId(wordLists),
                decoration: const InputDecoration(labelText: 'Word list *'),
                items:
                    wordLists
                        .map(
                          (list) => DropdownMenuItem(
                            value: list.id,
                            child: Text(list.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _selectedListId = value),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Choose CSV file',
                icon: Icons.upload_file_rounded,
                style: CustomButtonStyle.secondary,
                isLoading: _isPicking,
                onPressed: _isPicking ? null : _pickCsv,
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _isError
                            ? colors.error.withValues(alpha: 0.10)
                            : colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isError ? colors.error : colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (previewItems.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...previewItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.word,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(item.meaningVi),
                          if (item.phonetic.isNotEmpty ||
                              item.partOfSpeech.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                item.phonetic,
                                item.partOfSpeech,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_items.length > previewItems.length)
                  Text(
                    '+ ${_items.length - previewItems.length} more words',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      label: 'Cancel',
                      style: CustomButtonStyle.outline,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: 'Import',
                      icon: Icons.check_rounded,
                      isLoading: provider.isSaving,
                      onPressed:
                          _items.isEmpty || provider.isSaving
                              ? null
                              : _importCsv,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _safeSelectedListId(List<WordList> wordLists) {
    if (_selectedListId != null &&
        wordLists.any((list) => list.id == _selectedListId)) {
      return _selectedListId;
    }
    if (wordLists.isEmpty) return null;
    return wordLists.first.id;
  }
}
