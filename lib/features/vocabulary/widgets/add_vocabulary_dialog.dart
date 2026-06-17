import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../features/vocabulary/providers/word_list_provider.dart';
import '../../../features/vocabulary/models/word_list.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';

class AddVocabularyDialog extends StatefulWidget {
  const AddVocabularyDialog({this.initialListId, super.key});

  final String? initialListId;

  @override
  State<AddVocabularyDialog> createState() => _AddVocabularyDialogState();
}

class _AddVocabularyDialogState extends State<AddVocabularyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _meaningController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _partOfSpeechController = TextEditingController();
  final _exampleEnController = TextEditingController();
  final _exampleViController = TextEditingController();
  final _sourceContextController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _definitions = <_DefinitionFields>[_DefinitionFields()];

  String _lastLookupKey = '';
  String? _localError;
  List<String> _suggestions = [];
  bool _isLookingUp = false;
  int _tabIndex = 0;
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

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _phoneticController.dispose();
    _partOfSpeechController.dispose();
    _exampleEnController.dispose();
    _exampleViController.dispose();
    _sourceContextController.dispose();
    _imageUrlController.dispose();
    for (final definition in _definitions) {
      definition.dispose();
    }
    super.dispose();
  }

  void _handleWordChanged(String value) {
    final word = value.trim();
    setState(() {
      _suggestions = _buildSuggestions(word);
      _localError = null;
    });

    final lookedUpWord = _lastLookupKey.split('|').firstOrNull;
    if (lookedUpWord != null &&
        lookedUpWord.isNotEmpty &&
        lookedUpWord != word.toLowerCase()) {
      _lastLookupKey = '';
      _clearLookupFields();
    }
  }

  Future<void> _selectSuggestion(String suggestion) async {
    _wordController.text = suggestion;
    _wordController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    setState(() => _suggestions = []);
    await _lookupWithAI();
  }

  Future<void> _lookupWithAI() async {
    final word = _wordController.text.trim();
    if (word.isEmpty || _isLookingUp) return;

    final lookupKey = '${word.toLowerCase()}|${_sourceContextController.text}';
    if (lookupKey == _lastLookupKey && _meaningController.text.isNotEmpty) {
      return;
    }

    setState(() {
      _isLookingUp = true;
      _localError = null;
    });

    final result = await context.read<VocabularyProvider>().lookupWordWithAI(
      word: word,
      sourceContext: _sourceContextController.text,
    );
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLookingUp = false;
        _localError =
            context.read<VocabularyProvider>().errorMessage ??
            'Cannot lookup this word with AI.';
      });
      return;
    }

    _lastLookupKey = lookupKey;
    _applyLookupResult(result);
    setState(() {
      _isLookingUp = false;
      _localError = null;
      _suggestions = [];
    });
  }

  void _clearLookupFields() {
    _meaningController.clear();
    _phoneticController.clear();
    _partOfSpeechController.clear();
    _exampleEnController.clear();
    _exampleViController.clear();
    for (final definition in _definitions) {
      definition.dispose();
    }
    _definitions
      ..clear()
      ..add(_DefinitionFields());
  }

  void _applyLookupResult(VocabularyItem item) {
    _wordController.text = item.word;
    _meaningController.text = item.meaningVi;
    _phoneticController.text = item.phonetic;
    _partOfSpeechController.text = item.partOfSpeech;
    _exampleEnController.text = item.exampleEn;
    _exampleViController.text = item.exampleVi;

    for (final definition in _definitions) {
      definition.dispose();
    }
    _definitions
      ..clear()
      ..addAll(
        item.effectiveDefinitions.isEmpty
            ? [_DefinitionFields()]
            : item.effectiveDefinitions.map(_DefinitionFields.fromDefinition),
      );
  }

  List<String> _buildSuggestions(String input) {
    final word = input.trim().toLowerCase();
    if (word.length < 2) return const [];

    if (_tabIndex == 1 || word.contains(RegExp(r'\s+'))) {
      return [input.trim()];
    }

    final suggestions = <String>[word];
    final special = _specialSuggestions[word];
    if (special != null) suggestions.addAll(special);

    if (word.endsWith('y') && word.length > 2) {
      suggestions.add('${word.substring(0, word.length - 1)}ies');
    } else if (word.endsWith('s') ||
        word.endsWith('x') ||
        word.endsWith('ch') ||
        word.endsWith('sh')) {
      suggestions.add('${word}es');
    } else {
      suggestions.add('${word}s');
    }

    if (word.endsWith('e')) {
      suggestions.add('${word}d');
      suggestions.add('${word.substring(0, word.length - 1)}ing');
    } else {
      suggestions.add('${word}ed');
      suggestions.add('${word}ing');
    }
    suggestions.add('${word}er');
    suggestions.add('${word}est');
    suggestions.add('${word}ly');

    return suggestions
        .where((suggestion) => suggestion.trim().isNotEmpty)
        .toSet()
        .take(8)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<VocabularyProvider>();
    final word = _wordController.text.trim();
    final exists = await provider.checkWordExists(word);
    if (!mounted) return;

    var allowDuplicate = false;
    if (exists) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('This word already exists'),
              content: const Text('Do you want to save it anyway?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
      allowDuplicate = true;
    }

    final now = DateTime.now();
    final imageUrl = _imageUrlController.text.trim();
    final selectedListId = _selectedListId;
    if (selectedListId == null || selectedListId.trim().isEmpty) {
      setState(() {
        _localError = 'Please select a word list.';
      });
      return;
    }
    final item = VocabularyItem(
      id: '',
      userId: '',
      listId: selectedListId,
      word: word,
      meaningVi: _meaningController.text.trim(),
      phonetic: _phoneticController.text.trim(),
      partOfSpeech: _partOfSpeechController.text.trim(),
      exampleEn: _exampleEnController.text.trim(),
      exampleVi: _exampleViController.text.trim(),
      sourceContext: _sourceContextController.text.trim(),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      definitions: _readDefinitions(),
      createdAt: now,
      updatedAt: now,
    );

    final success = await provider.addManualVocabulary(
      item,
      allowDuplicate: allowDuplicate,
    );
    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _localError = provider.errorMessage ?? 'Cannot save vocabulary.';
    });
  }

  List<VocabularyDefinition> _readDefinitions() {
    return _definitions
        .map(
          (definition) => VocabularyDefinition(
            partOfSpeech: definition.partOfSpeech.text.trim(),
            meaningVi: definition.meaningVi.text.trim(),
          ),
        )
        .where(
          (definition) =>
              definition.partOfSpeech.isNotEmpty ||
              definition.meaningVi.isNotEmpty,
        )
        .toList();
  }

  void _addDefinition() {
    setState(() => _definitions.add(_DefinitionFields()));
  }

  void _removeDefinition(int index) {
    if (_definitions.length == 1) {
      _definitions.first.partOfSpeech.clear();
      _definitions.first.meaningVi.clear();
      setState(() {});
      return;
    }
    final removed = _definitions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    final wordListProvider = context.watch<WordListProvider>();
    final colors = Theme.of(context).colorScheme;
    final wordLabel = _tabIndex == 0 ? 'Word *' : 'Phrase / Sentence *';
    final wordLists = wordListProvider.wordLists;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: DefaultTabController(
          length: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add new word',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    onTap: (index) => setState(() => _tabIndex = index),
                    tabs: const [
                      Tab(text: 'Word'),
                      Tab(text: 'Phrase / Sentence'),
                    ],
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
                    onChanged:
                        (value) => setState(() => _selectedListId = value),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please select a word list.'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _wordController,
                    decoration: InputDecoration(
                      labelText: wordLabel,
                      suffixIcon:
                          _isLookingUp
                              ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : IconButton(
                                tooltip: 'Look up with AI',
                                onPressed: _lookupWithAI,
                                icon: const Icon(Icons.auto_awesome_rounded),
                              ),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: _handleWordChanged,
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a word or phrase.'
                                : null,
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _suggestions
                                .map(
                                  (suggestion) => ActionChip(
                                    avatar: const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                    ),
                                    label: Text(suggestion),
                                    onPressed:
                                        _isLookingUp
                                            ? null
                                            : () =>
                                                _selectSuggestion(suggestion),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Look up with AI',
                    icon: Icons.auto_awesome_rounded,
                    style: CustomButtonStyle.secondary,
                    isLoading: _isLookingUp,
                    onPressed: _lookupWithAI,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Translation *',
                    ),
                    textInputAction: TextInputAction.next,
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a translation.'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneticController,
                          decoration: const InputDecoration(
                            labelText: 'Phonetic',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _partOfSpeechController,
                          decoration: const InputDecoration(
                            labelText: 'Part of speech',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Definitions',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addDefinition,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add definition'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_definitions.length, (index) {
                    final definition = _definitions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: definition.partOfSpeech,
                              decoration: const InputDecoration(
                                labelText: 'Part of speech',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: definition.meaningVi,
                              decoration: const InputDecoration(
                                labelText: 'Vietnamese meaning',
                              ),
                              minLines: 1,
                              maxLines: 2,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove definition',
                            onPressed: () => _removeDefinition(index),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _exampleEnController,
                    decoration: const InputDecoration(
                      labelText: 'English example',
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _exampleViController,
                    decoration: const InputDecoration(
                      labelText: 'Vietnamese example translation',
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sourceContextController,
                    decoration: const InputDecoration(
                      labelText: 'Source context',
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      final url = value?.trim() ?? '';
                      if (url.isEmpty) return null;
                      if (!url.startsWith('https://')) {
                        return 'Image URL must start with https://';
                      }
                      return null;
                    },
                  ),
                  if (_localError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _localError!,
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                          label: 'Add word',
                          icon: Icons.add_rounded,
                          isLoading: provider.isSaving,
                          onPressed: provider.isSaving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

const _specialSuggestions = <String, List<String>>{
  'good': ['goods', 'goodness', 'good-looking', 'better', 'best'],
  'bad': ['worse', 'worst', 'badly'],
  'happy': ['happiness', 'happily', 'happier', 'happiest'],
  'beauty': ['beautiful', 'beautifully'],
};

class _DefinitionFields {
  _DefinitionFields({String partOfSpeech = '', String meaningVi = ''})
    : partOfSpeech = TextEditingController(text: partOfSpeech),
      meaningVi = TextEditingController(text: meaningVi);

  _DefinitionFields.fromDefinition(VocabularyDefinition definition)
    : this(
        partOfSpeech: definition.partOfSpeech,
        meaningVi: definition.meaningVi,
      );

  final TextEditingController partOfSpeech;
  final TextEditingController meaningVi;

  void dispose() {
    partOfSpeech.dispose();
    meaningVi.dispose();
  }
}
