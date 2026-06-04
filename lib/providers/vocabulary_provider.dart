import 'package:flutter/foundation.dart';

import '../models/vocabulary_item.dart';
import '../services/ai_dictionary_service.dart';
import '../services/tts_service.dart';
import '../services/vocabulary_service.dart';

class VocabularyProvider extends ChangeNotifier {
  VocabularyProvider({
    required VocabularyService vocabularyService,
    required AiDictionaryService aiDictionaryService,
    required TtsService ttsService,
  }) : _vocabularyService = vocabularyService,
       _aiDictionaryService = aiDictionaryService,
       _ttsService = ttsService;

  final VocabularyService _vocabularyService;
  final AiDictionaryService _aiDictionaryService;
  final TtsService _ttsService;

  List<VocabularyItem> items = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  int get totalWords => items.length;
  int get favoriteWords => items.where((item) => item.isFavorite).length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _vocabularyService.loadVocabulary();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshVocabulary() => load();

  Future<bool> save(VocabularyItem item) async {
    isLoading = true;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _vocabularyService.saveVocabulary(item);
      items = [saved, ...items.where((value) => value.id != saved.id)];
      isLoading = false;
      isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<VocabularyItem?> lookupWordWithAI({
    required String word,
    String sourceContext = '',
  }) async {
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      errorMessage = 'Please enter an English word or phrase.';
      notifyListeners();
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _aiDictionaryService.lookupWord(
        word: trimmedWord,
        sourceContext: sourceContext,
      );
      isLoading = false;
      notifyListeners();
      return result;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkWordExists(String word) async {
    try {
      return await _vocabularyService.checkWordExists(word);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> addManualVocabulary(
    VocabularyItem item, {
    bool allowDuplicate = false,
  }) async {
    final trimmedWord = item.word.trim();
    if (trimmedWord.isEmpty) {
      errorMessage = 'Please enter an English word or phrase.';
      notifyListeners();
      return false;
    }
    if (item.meaningVi.trim().isEmpty) {
      errorMessage = 'Please enter Vietnamese meaning.';
      notifyListeners();
      return false;
    }
    if ((item.imageUrl ?? '').isNotEmpty &&
        !item.imageUrl!.trim().startsWith('https://')) {
      errorMessage = 'Image URL must start with https://';
      notifyListeners();
      return false;
    }
    if (!allowDuplicate &&
        await _vocabularyService.checkWordExists(item.word)) {
      errorMessage = 'This word already exists.';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _vocabularyService.addVocabulary(
        item,
        allowDuplicate: allowDuplicate,
      );
      items = [saved, ...items.where((value) => value.id != saved.id)];
      isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<int> addManyVocabulary(List<VocabularyItem> vocabularyItems) async {
    if (vocabularyItems.isEmpty) return 0;

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _vocabularyService.addManyVocabulary(vocabularyItems);
      items = [
        ...saved,
        ...items.where(
          (item) => !saved.any((savedItem) => savedItem.id == item.id),
        ),
      ];
      isSaving = false;
      notifyListeners();
      return saved.length;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return 0;
    }
  }

  Future<int> importVocabularyFromCsv(List<VocabularyItem> vocabularyItems) {
    return addManyVocabulary(vocabularyItems);
  }

  Future<void> toggleFavorite(VocabularyItem item) async {
    try {
      final updated = await _vocabularyService.toggleFavorite(item);
      items =
          items
              .map((value) => value.id == updated.id ? updated : value)
              .toList();
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> delete(VocabularyItem item) async {
    try {
      await _vocabularyService.deleteVocabulary(item);
      items = items.where((value) => value.id != item.id).toList();
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> speak(String text) => _ttsService.speak(text);
}
